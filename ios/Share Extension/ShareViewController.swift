import MobileCoreServices
import Social
import UIKit
import UniformTypeIdentifiers

private let appGroupId = "group.sa.com.digitalharbor.saqqar"
private let hostBundleId = "sa.com.digitalharbor.saqqarapp"
private let shareScheme = "ShareMedia-\(hostBundleId)"
private let shareKey = "ShareKey"
private let shareMessageKey = "ShareMessageKey"

private struct SharedMediaFile: Codable {
    let path: String
    let mimeType: String?
    let thumbnail: String?
    let duration: Double?
    let message: String?
    let type: SharedMediaType
}

private enum SharedMediaType: String, Codable {
    case image
    case video
    case text
    case file
    case url
}

private struct ShareAttachmentType {
    let identifier: String
    let type: SharedMediaType
}

final class ShareViewController: SLComposeServiceViewController {
    private var didStartProcessing = false

    private var supportedTypes: [ShareAttachmentType] {
        if #available(iOS 14.0, *) {
            // Order matters: `hasItemConformingToTypeIdentifier` matches on UTI
            // conformance, and every file URL (`public.file-url`) also conforms
            // to the generic `public.url`. `.fileURL`/`.data` MUST be checked
            // before `.url`, or any shared document that isn't specifically an
            // image/movie (PDF, spreadsheet, zip, etc.) gets misclassified as
            // a plain link — its bytes never get copied into the app group,
            // and the host app's Dart-side intake explicitly drops `url` items.
            return [
                // `public.jpeg` before `public.image`: an iPhone photo is
                // HEIC on disk, and Flutter's image decoder has no HEIC
                // support — a shared photo would reach the chat as a file
                // the app cannot draw. Photos registers a JPEG
                // representation alongside the HEIC one, so asking for it
                // first gets a decodable file. Providers that offer no JPEG
                // simply fail the conformance check and fall through to
                // `public.image` below, unchanged.
                ShareAttachmentType(identifier: UTType.jpeg.identifier, type: .image),
                ShareAttachmentType(identifier: UTType.image.identifier, type: .image),
                ShareAttachmentType(identifier: UTType.movie.identifier, type: .video),
                ShareAttachmentType(identifier: UTType.fileURL.identifier, type: .file),
                ShareAttachmentType(identifier: UTType.pdf.identifier, type: .file),
                ShareAttachmentType(identifier: UTType.data.identifier, type: .file),
                ShareAttachmentType(identifier: UTType.content.identifier, type: .file),
                ShareAttachmentType(identifier: UTType.item.identifier, type: .file),
                ShareAttachmentType(identifier: UTType.url.identifier, type: .url),
                ShareAttachmentType(identifier: UTType.text.identifier, type: .text),
            ]
        }

        return [
            ShareAttachmentType(identifier: kUTTypeImage as String, type: .image),
            ShareAttachmentType(identifier: kUTTypeMovie as String, type: .video),
            ShareAttachmentType(identifier: kUTTypeFileURL as String, type: .file),
            ShareAttachmentType(identifier: "com.adobe.pdf", type: .file),
            ShareAttachmentType(identifier: kUTTypeData as String, type: .file),
            ShareAttachmentType(identifier: kUTTypeContent as String, type: .file),
            ShareAttachmentType(identifier: kUTTypeItem as String, type: .file),
            ShareAttachmentType(identifier: kUTTypeURL as String, type: .url),
            ShareAttachmentType(identifier: kUTTypeText as String, type: .text),
        ]
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.alpha = 0.01
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard !didStartProcessing else {
            return
        }

        didStartProcessing = true
        processSharedItems()
    }

    override func isContentValid() -> Bool {
        true
    }

    override func didSelectPost() {
        processSharedItems()
    }

    override func configurationItems() -> [Any]! {
        []
    }

    private func processSharedItems() {
        let attachments = extensionContext?.inputItems
            .compactMap { $0 as? NSExtensionItem }
            .flatMap { $0.attachments ?? [] } ?? []

        guard !attachments.isEmpty else {
            saveAndRedirect([])
            return
        }

        let group = DispatchGroup()
        var files: [SharedMediaFile] = []
        let lock = NSLock()

        for attachment in attachments {
            guard let attachmentType = resolvedAttachmentType(for: attachment) else {
                continue
            }

            group.enter()
            loadSharedMediaFile(
                from: attachment,
                attachmentType: attachmentType
            ) { file in
                if let file {
                    lock.lock()
                    files.append(file)
                    lock.unlock()
                }
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            self?.saveAndRedirect(files)
        }
    }

    private func resolvedAttachmentType(for attachment: NSItemProvider) -> ShareAttachmentType? {
        if let supportedType = supportedTypes.first(where: { attachment.hasItemConformingToTypeIdentifier($0.identifier) }) {
            return supportedType
        }

        guard let firstRegisteredType = attachment.registeredTypeIdentifiers.first else {
            return nil
        }

        return ShareAttachmentType(identifier: firstRegisteredType, type: .file)
    }

    private func loadSharedMediaFile(
        from attachment: NSItemProvider,
        attachmentType: ShareAttachmentType,
        completion: @escaping (SharedMediaFile?) -> Void
    ) {
        let carriesBytes = attachmentType.type == .file
            || attachmentType.type == .image
            || attachmentType.type == .video
        let urlBacked = isURLBackedItem(
            attachment,
            matching: attachmentType.identifier
        )

        if carriesBytes && !urlBacked {
            attachment.loadFileRepresentation(forTypeIdentifier: attachmentType.identifier) { [weak self] url, _ in
                guard let self else {
                    completion(nil)
                    return
                }

                if let url,
                   let file = self.makeSharedMediaFile(
                    from: url as NSSecureCoding,
                    type: attachmentType.type,
                    suggestedName: attachment.suggestedName,
                    typeIdentifier: attachmentType.identifier,
                    urlBacked: false
                   ) {
                    completion(file)
                    return
                }

                self.loadSharedMediaItem(
                    from: attachment,
                    attachmentType: attachmentType,
                    urlBacked: urlBacked,
                    completion: completion
                )
            }
            return
        }

        loadSharedMediaItem(
            from: attachment,
            attachmentType: attachmentType,
            urlBacked: urlBacked,
            completion: completion
        )
    }

    private func loadSharedMediaItem(
        from attachment: NSItemProvider,
        attachmentType: ShareAttachmentType,
        urlBacked: Bool,
        completion: @escaping (SharedMediaFile?) -> Void
    ) {
        attachment.loadItem(forTypeIdentifier: attachmentType.identifier, options: nil) { [weak self] item, _ in
            guard let self else {
                completion(nil)
                return
            }

            completion(self.makeSharedMediaFile(
                from: item,
                type: attachmentType.type,
                suggestedName: attachment.suggestedName,
                typeIdentifier: attachmentType.identifier,
                urlBacked: urlBacked
            ))
        }
    }

    /// Whether the bytes behind this attachment are unreachable through
    /// `loadFileRepresentation`.
    ///
    /// That call asks the provider for the *data* representation of an
    /// identifier. When the item is really a URL, that data is the URL string —
    /// `NSURL`'s item-provider payload is `url.dataRepresentation` — so iOS
    /// writes a temp file whose CONTENTS are the text `file:///…/report.pdf`
    /// and we'd copy that one-line file into the app group as if it were the
    /// document. That is the "a link arrives instead of the file" report.
    ///
    /// There are two ways to land there, and the first check alone misses the
    /// second:
    ///   * the matched identifier is a URL type outright (`public.file-url`);
    ///   * the item registers only `public.url`, which conforms to
    ///     `public.data` — so the generic `.data` row in `supportedTypes`
    ///     matches first and hides the URL-ness behind a data identifier.
    ///
    /// Both have to go through `loadItem`, which hands back a real `URL` whose
    /// bytes we can copy. The `allSatisfy` is deliberately strict: an item that
    /// registers a concrete type *alongside* a URL type (a PDF that also offers
    /// `public.file-url`) does have real bytes, and stays on the fast path.
    private func isURLBackedItem(
        _ attachment: NSItemProvider,
        matching identifier: String
    ) -> Bool {
        if isURLTypeIdentifier(identifier) {
            return true
        }

        let registered = attachment.registeredTypeIdentifiers
        return !registered.isEmpty && registered.allSatisfy { isURLTypeIdentifier($0) }
    }

    /// True for `public.url` and everything conforming to it, `public.file-url`
    /// included. Those identifiers name a URL *object*, never the bytes behind
    /// it.
    private func isURLTypeIdentifier(_ identifier: String) -> Bool {
        if #available(iOS 14.0, *) {
            guard let type = UTType(identifier) else {
                return false
            }
            return type.conforms(to: .url)
        }

        return UTTypeConformsTo(identifier as CFString, kUTTypeURL)
    }

    /// Recovers the file URL from a `public.file-url` item that arrived in a
    /// shape other than `URL`. Providers may deliver it as `NSURL`, as the raw
    /// UTF-8 bytes of the absolute string, or as the string itself; only the
    /// first reaches the `URL` branch of `makeSharedMediaFile` unaided, and the
    /// other two would otherwise be persisted verbatim — a "file" containing a
    /// link, the same defect from the other direction.
    private func fileURL(from item: NSSecureCoding?) -> URL? {
        switch item {
        case let url as URL:
            return url.isFileURL ? url : nil
        case let data as Data:
            guard let text = String(data: data, encoding: .utf8) else {
                return nil
            }
            return fileURL(fromString: text)
        case let text as String:
            return fileURL(fromString: text)
        default:
            return nil
        }
    }

    private func fileURL(fromString text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        if let url = URL(string: trimmed), url.isFileURL {
            return url
        }

        return trimmed.hasPrefix("/") ? URL(fileURLWithPath: trimmed) : nil
    }

    private func makeSharedMediaFile(
        from item: NSSecureCoding?,
        type: SharedMediaType,
        suggestedName: String?,
        typeIdentifier: String,
        urlBacked: Bool
    ) -> SharedMediaFile? {
        var item = item

        // Normalise a file-URL payload back to a `URL` before the switch, so a
        // provider that hands it over as bytes or as a string still copies the
        // document rather than the link that points at it. Gated on `urlBacked`
        // so a genuine document's bytes are never reinterpreted as a path.
        if type != .url, urlBacked, let resolved = fileURL(from: item) {
            item = resolved as NSSecureCoding
        }

        switch item {
        case let url as URL:
            if type == .url {
                return SharedMediaFile(
                    path: url.absoluteString,
                    mimeType: nil,
                    thumbnail: nil,
                    duration: nil,
                    message: nil,
                    type: .url
                )
            }

            guard let copiedURL = copyToSharedContainer(url) else {
                return nil
            }

            return SharedMediaFile(
                path: copiedURL.absoluteString.removingPercentEncoding ?? copiedURL.absoluteString,
                mimeType: copiedURL.mimeType,
                thumbnail: nil,
                duration: nil,
                message: nil,
                type: type
            )

        case let image as UIImage:
            guard let imageURL = writeImageToSharedContainer(image) else {
                return nil
            }

            return SharedMediaFile(
                path: imageURL.absoluteString.removingPercentEncoding ?? imageURL.absoluteString,
                mimeType: "image/png",
                thumbnail: nil,
                duration: nil,
                message: nil,
                type: .image
            )

        case let text as String:
            return SharedMediaFile(
                path: text,
                mimeType: type == .text ? "text/plain" : nil,
                thumbnail: nil,
                duration: nil,
                message: nil,
                type: type == .url ? .url : .text
            )

        case let data as Data:
            guard let dataURL = writeDataToSharedContainer(
                data,
                suggestedName: suggestedName,
                typeIdentifier: typeIdentifier
            ) else {
                return nil
            }

            return SharedMediaFile(
                path: dataURL.absoluteString.removingPercentEncoding ?? dataURL.absoluteString,
                mimeType: dataURL.mimeType,
                thumbnail: nil,
                duration: nil,
                message: nil,
                type: type
            )

        default:
            return nil
        }
    }

    private func copyToSharedContainer(_ sourceURL: URL) -> URL? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
            return nil
        }

        let didStartAccessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let fileName = sourceURL.lastPathComponent.isEmpty ? UUID().uuidString : sourceURL.lastPathComponent
        let destinationURL = containerURL.appendingPathComponent(fileName)

        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            hardenSharedFile(destinationURL)
            return destinationURL
        } catch {
            return nil
        }
    }

    private func writeImageToSharedContainer(_ image: UIImage) -> URL? {
        guard
            let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId),
            let data = image.pngData()
        else {
            return nil
        }

        let destinationURL = containerURL.appendingPathComponent("\(UUID().uuidString).png")

        do {
            try data.write(to: destinationURL, options: .atomic)
            hardenSharedFile(destinationURL)
            return destinationURL
        } catch {
            return nil
        }
    }

    private func writeDataToSharedContainer(
        _ data: Data,
        suggestedName: String?,
        typeIdentifier: String
    ) -> URL? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
            return nil
        }

        let destinationURL = containerURL.appendingPathComponent(
            fileName(suggestedName: suggestedName, typeIdentifier: typeIdentifier)
        )

        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try data.write(to: destinationURL, options: .atomic)
            hardenSharedFile(destinationURL)
            return destinationURL
        } catch {
            return nil
        }
    }

    /// Encrypts a file written into the shared App-Group container at rest
    /// (readable after first unlock, matching the app's token store) and marks
    /// it excluded from iCloud/iTunes backups. Without this, user-shared
    /// documents (PDFs, images, arbitrary data) sat in the container with the
    /// default protection AND were eligible for device backups. Best-effort:
    /// a failure here never blocks the share.
    private func hardenSharedFile(_ url: URL) {
        var target = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? target.setResourceValues(values)
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: url.path
        )
    }

    private func fileName(suggestedName: String?, typeIdentifier: String) -> String {
        if let suggestedName, !suggestedName.isEmpty {
            return suggestedName
        }

        if #available(iOS 14.0, *),
           let fileExtension = UTType(typeIdentifier)?.preferredFilenameExtension {
            return "\(UUID().uuidString).\(fileExtension)"
        }

        return UUID().uuidString
    }

    private func saveAndRedirect(_ files: [SharedMediaFile]) {
        let userDefaults = UserDefaults(suiteName: appGroupId)
        userDefaults?.set(try? JSONEncoder().encode(files), forKey: shareKey)
        userDefaults?.set(nil, forKey: shareMessageKey)
        userDefaults?.set(files.count, forKey: "SaqqarShareDebugFileCount")
        userDefaults?.set(Date().timeIntervalSince1970, forKey: "SaqqarShareDebugSavedAt")
        userDefaults?.synchronize()

        redirectToHostApp()
    }

    private func redirectToHostApp() {
        guard let url = URL(string: "\(shareScheme):share") else {
            extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            return
        }

        var responder: UIResponder? = self

        if #available(iOS 18.0, *) {
            while let currentResponder = responder {
                if let application = currentResponder as? UIApplication {
                    application.open(url, options: [:], completionHandler: nil)
                    break
                }
                responder = currentResponder.next
            }
        } else {
            let selector = sel_registerName("openURL:")

            while let currentResponder = responder {
                if currentResponder.responds(to: selector) {
                    _ = currentResponder.perform(selector, with: url)
                    break
                }
                responder = currentResponder.next
            }
        }

        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}

private extension URL {
    var mimeType: String {
        if #available(iOS 14.0, *),
           let mimeType = UTType(filenameExtension: pathExtension)?.preferredMIMEType {
            return mimeType
        }

        guard
            let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExtension as NSString, nil)?.takeRetainedValue(),
            let mimeType = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType)?.takeRetainedValue()
        else {
            return "application/octet-stream"
        }

        return mimeType as String
    }
}
