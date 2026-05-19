import 'dart:io';

import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import 'artifact_models.dart';

/// Downloads an [Artifact] to local storage and hands it off to the
/// OS's matching viewer (PDF → Adobe Acrobat / Drive, DOCX → Word /
/// Docs, XLSX → Excel / Sheets, image → gallery, etc.).
///
/// Saves under the app's documents directory so we don't need a
/// runtime storage permission — the per-app sandbox is always
/// writable. Same file downloaded twice reuses the cached copy
/// instead of refetching, which makes "open again" feel instant.
class ArtifactDownloader {
  ArtifactDownloader(this._dio);

  final Dio _dio;

  /// Downloads [artifact] (or reuses the cached copy) and opens it.
  /// Returns an [ArtifactOpenResult] so the caller can surface a
  /// localized error toast on failure.
  Future<ArtifactOpenResult> downloadAndOpen(Artifact artifact) {
    return downloadAndOpenUrl(
      url: artifact.absoluteUrl,
      cacheKey: artifact.id,
      originalName: artifact.name,
      kindHint: artifact.kind,
    );
  }

  /// Generic variant — both artifacts and message attachments use it.
  /// Caches by [cacheKey] so the same id won't re-download even across
  /// app restarts. [originalName] supplies the extension; [kindHint]
  /// is a fallback when the name has none (e.g. UUID-only filenames).
  Future<ArtifactOpenResult> downloadAndOpenUrl({
    required String url,
    required String cacheKey,
    required String originalName,
    String kindHint = '',
  }) async {
    try {
      final file = await _ensureDownloaded(
        url: url,
        cacheKey: cacheKey,
        originalName: originalName,
        kindHint: kindHint,
      );
      final open = await OpenFilex.open(file.path);
      switch (open.type) {
        case ResultType.done:
          return const ArtifactOpenResult.success();
        case ResultType.noAppToOpen:
          return const ArtifactOpenResult.noViewer();
        case ResultType.permissionDenied:
        case ResultType.fileNotFound:
        case ResultType.error:
          return ArtifactOpenResult.openFailed(open.message);
      }
    } on DioException catch (e) {
      return ArtifactOpenResult.downloadFailed(
        e.response?.statusCode,
        e.message ?? e.toString(),
      );
    } catch (e) {
      return ArtifactOpenResult.downloadFailed(null, e.toString());
    }
  }

  /// Returns the on-disk file. Downloads it if not already cached.
  Future<File> _ensureDownloaded({
    required String url,
    required String cacheKey,
    required String originalName,
    String kindHint = '',
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final saqqarDir = Directory('${dir.path}/saqqar_artifacts');
    if (!saqqarDir.existsSync()) {
      saqqarDir.createSync(recursive: true);
    }
    // Filename = cacheKey + extension from the original name. Keeps
    // the file path stable across re-downloads (id-keyed cache) while
    // preserving the extension so the OS picks the right viewer.
    final safeName = _safeFilename(cacheKey, originalName, kindHint);
    final target = File('${saqqarDir.path}/$safeName');
    if (target.existsSync() && target.lengthSync() > 0) {
      return target;
    }
    // Artifact URLs are unguessable per spec §9 ("the URL itself is
    // the auth token"). Still send through the normal Dio instance so
    // the AuthInterceptor attaches our bearer in case the server is
    // configured to require it on a future revision.
    await _dio.download(url, target.path);
    return target;
  }

  /// `<cacheKey>.<ext>` so we can dedupe across re-downloads but still
  /// hand the OS a familiar extension. Falls back to `.bin` when we
  /// can't detect one.
  String _safeFilename(
    String cacheKey,
    String originalName,
    String kindHint,
  ) {
    final original = originalName.trim();
    var ext = '';
    final dot = original.lastIndexOf('.');
    if (dot != -1 && dot < original.length - 1) {
      ext = original.substring(dot + 1).toLowerCase();
    } else if (kindHint.isNotEmpty) {
      ext = kindHint.toLowerCase();
    }
    if (ext.isEmpty || ext.length > 6) ext = 'bin';
    return '$cacheKey.$ext';
  }
}

/// Typed outcome of an "open this artifact" attempt. The view uses
/// this to pick the right localized toast — `success` stays silent,
/// the rest surface specific messages.
sealed class ArtifactOpenResult {
  const ArtifactOpenResult();

  const factory ArtifactOpenResult.success() = ArtifactOpenSuccess;
  const factory ArtifactOpenResult.noViewer() = ArtifactOpenNoViewer;
  const factory ArtifactOpenResult.openFailed(String message) =
      ArtifactOpenFailed;
  const factory ArtifactOpenResult.downloadFailed(
    int? statusCode,
    String message,
  ) = ArtifactDownloadFailed;
}

class ArtifactOpenSuccess extends ArtifactOpenResult {
  const ArtifactOpenSuccess();
}

class ArtifactOpenNoViewer extends ArtifactOpenResult {
  const ArtifactOpenNoViewer();
}

class ArtifactOpenFailed extends ArtifactOpenResult {
  const ArtifactOpenFailed(this.message);
  final String message;
}

class ArtifactDownloadFailed extends ArtifactOpenResult {
  const ArtifactDownloadFailed(this.statusCode, this.message);
  final int? statusCode;
  final String message;
}
