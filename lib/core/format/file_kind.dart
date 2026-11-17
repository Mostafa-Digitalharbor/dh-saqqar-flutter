import '../constants/ui_strings.dart';

/// What a file *is*, decided from its extension.
///
/// ## Why this exists
///
/// Five places classified file extensions independently, and they did not
/// agree — least of all about what counts as an image:
///
/// | site | image extensions |
/// |---|---|
/// | the composer chip (`chat_screen`) | png jpg jpeg gif webp |
/// | the artifact tile | png jpg jpeg gif webp |
/// | the in-app viewer | png jpg jpeg gif webp **bmp** |
/// | the message-bubble thumbnail | png jpg jpeg gif webp bmp **heic heif** |
/// | the Files picker's allow-list | png jpg jpeg gif webp |
///
/// That is not a tidiness problem. **HEIC is what an iPhone camera saves**,
/// and the photo picker is `FileType.image` — so it hands back `.heic`
/// whatever the allow-list says. One such photo was labelled "HEIC" instead
/// of "Image" in the composer, drew a thumbnail in the sent message, and then
/// refused to open in the viewer as "we can't display this file". Three
/// components, three answers, one file.
///
/// One table, one answer. Adding a format is one edit here and every surface
/// follows.
enum FileKind {
  image,
  pdf,
  spreadsheet,
  csv,
  document,
  json,
  text,
  archive,
  other;

  /// Whether the in-app viewer can show this verbatim as text.
  ///
  /// [csv] and [json] are separate kinds because they get their own badge and
  /// icon elsewhere; for the viewer they are all just characters.
  bool get isTextRenderable =>
      this == FileKind.csv || this == FileKind.json || this == FileKind.text;
}

/// The single extension table behind [FileKind].
class FileKinds {
  FileKinds._();

  /// Everything a user would call a picture.
  ///
  /// `heic`/`heif` are the iPhone camera's own formats and are load-bearing,
  /// not completeness: the photo picker returns them regardless of any
  /// allow-list. Android cannot always decode HEIC, which is fine — the
  /// viewer's `Image.file` carries an `errorBuilder` that falls back to
  /// "open in another app", and that is a better outcome than refusing the
  /// file outright.
  static const Set<String> image = {
    'png',
    'jpg',
    'jpeg',
    'gif',
    'webp',
    'bmp',
    'heic',
    'heif',
  };

  static const Set<String> pdf = {'pdf'};
  static const Set<String> spreadsheet = {'xlsx', 'xls', 'xlsm'};
  static const Set<String> csv = {'csv', 'tsv'};
  static const Set<String> document = {'docx', 'doc'};
  static const Set<String> json = {'json'};

  /// Text-shaped formats the viewer can print as-is. Mostly agent output —
  /// logs, dumps, generated SQL.
  static const Set<String> text = {
    'txt',
    'md',
    'log',
    'xml',
    'yaml',
    'yml',
    'ini',
    'sql',
    'html',
  };

  /// Archives carry the 500 MB cap (Odoo addon bundles); everything else is
  /// 25 MB. Mirrors the server's per-kind limit.
  static const Set<String> archive = {'zip', 'tar', 'gz', 'tgz'};

  /// What the Files picker offers.
  ///
  /// Deliberately narrower than the union of the sets above: it is an *upload*
  /// allow-list, so it lists what the agent can usefully read, not everything
  /// the app can classify. Images are included so a user who keeps screenshots
  /// in Files can still reach them.
  static const List<String> pickerExtensions = [
    ...image,
    ...pdf,
    ...csv,
    ...spreadsheet,
    ...document,
    ...archive,
  ];

  /// The lowercase extension of [nameOrExtension].
  ///
  /// Accepts either a filename (`report.xlsx`) or a bare extension (`xlsx`),
  /// because call sites have one or the other and neither should have to
  /// normalize first. A leading dot is tolerated.
  static String extensionOf(String? nameOrExtension) {
    final value = (nameOrExtension ?? '').trim().toLowerCase();
    if (value.isEmpty) return '';
    final dot = value.lastIndexOf('.');
    return dot == -1 ? value : value.substring(dot + 1);
  }

  static FileKind of(String? nameOrExtension) {
    final ext = extensionOf(nameOrExtension);
    if (ext.isEmpty) return FileKind.other;
    if (image.contains(ext)) return FileKind.image;
    if (pdf.contains(ext)) return FileKind.pdf;
    if (spreadsheet.contains(ext)) return FileKind.spreadsheet;
    if (csv.contains(ext)) return FileKind.csv;
    if (document.contains(ext)) return FileKind.document;
    if (json.contains(ext)) return FileKind.json;
    if (text.contains(ext)) return FileKind.text;
    if (archive.contains(ext)) return FileKind.archive;
    return FileKind.other;
  }

  static bool isImage(String? nameOrExtension) =>
      of(nameOrExtension) == FileKind.image;

  static bool isArchive(String? nameOrExtension) =>
      of(nameOrExtension) == FileKind.archive;

  /// The uppercase format badge shown on chips and tiles ("XLSX", "PDF").
  ///
  /// Format identifiers, never translated — they read the same in Arabic,
  /// which is why they live in [UiStrings] rather than `app_strings`. The
  /// *category* word beside them ("Image" / "صورة") does translate and stays
  /// at the call site, which is the only place with a `BuildContext`.
  ///
  /// An unknown extension renders its own first five characters rather than a
  /// generic label: "PPTX" tells the user more than "FILE" does.
  static String badge(String? nameOrExtension) {
    final ext = extensionOf(nameOrExtension);
    return switch (of(ext)) {
      FileKind.pdf => UiStrings.formatPdf,
      FileKind.spreadsheet => UiStrings.formatXlsx,
      FileKind.csv => UiStrings.formatCsv,
      FileKind.document => UiStrings.formatDocx,
      FileKind.json => UiStrings.formatJson,
      FileKind.archive => UiStrings.formatZip,
      FileKind.other when ext.isEmpty => UiStrings.formatUnknown,
      _ => (ext.length > 5 ? ext.substring(0, 5) : ext).toUpperCase(),
    };
  }
}
