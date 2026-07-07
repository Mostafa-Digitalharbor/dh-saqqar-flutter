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
                ShareAttachmentType(identifier: UTType.image.identifier, type: .image),
                ShareAttachmentType(identifier: UTType.movie.identifier, type: .video),
                ShareAttachmentType(identifier: UTType.fileURL.identifier, type: .file),
                ShareAttachmentType(identifier: UTType.data.identifier, type: .file),
                ShareAttachmentType(identifier: UTType.url.identifier, type: .url),
                ShareAttachmentType(identifier: UTType.text.identifier, type: .text),
            ]
        }

        return [
            ShareAttachmentType(identifier: kUTTypeImage as String, type: .image),
            ShareAttachmentType(identifier: kUTTypeMovie as String, type: .video),
            ShareAttachmentType(identifier: kUTTypeFileURL as String, type: .file),
            ShareAttachmentType(identifier: kUTTypeData as String, type: .file),
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
            guard let attachmentType = supportedTypes.first(where: { attachment.hasItemConformingToTypeIdentifier($0.identifier) }) else {
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

    private func loadSharedMediaFile(
        from attachment: NSItemProvider,
        attachmentType: ShareAttachmentType,
        completion: @escaping (SharedMediaFile?) -> Void
    ) {
        if attachmentType.type == .file || attachmentType.type == .image || attachmentType.type == .video {
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
                    typeIdentifier: attachmentType.identifier
                   ) {
                    completion(file)
                    return
                }

                self.loadSharedMediaItem(
                    from: attachment,
                    attachmentType: attachmentType,
                    completion: completion
                )
            }
            return
        }

        loadSharedMediaItem(
            from: attachment,
            attachmentType: attachmentType,
            completion: completion
        )
    }

    private func loadSharedMediaItem(
        from attachment: NSItemProvider,
        attachmentType: ShareAttachmentType,
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
                typeIdentifier: attachmentType.identifier
            ))
        }
    }

    private func makeSharedMediaFile(
        from item: NSSecureCoding?,
        type: SharedMediaType,
        suggestedName: String?,
        typeIdentifier: String
    ) -> SharedMediaFile? {
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
        values.fileProtection = .completeUntilFirstUserAuthentication
        try? target.setResourceValues(values)
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
