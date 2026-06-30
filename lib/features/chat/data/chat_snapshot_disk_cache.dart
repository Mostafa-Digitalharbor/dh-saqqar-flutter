import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../../core/logging/app_logger.dart';

/// On-disk cache for conversation snapshots, stored as the **raw JSON body**
/// the server sent (one file per conversation).
///
/// Two design choices make this fast and jank-free:
///   * We persist the response **verbatim as a string** — no model
///     serialization, and (critically) the background prefetch can write
///     it WITHOUT ever decoding the JSON, so warming 30 conversations costs
///     network + a file write each and zero parse work on the UI isolate.
///   * Decoding back into a model happens lazily, off the UI isolate
///     (`compute`), only when the user actually opens that chat — see
///     `ConversationsRepository.diskCachedSnapshot`.
///
/// The directory resolves lazily on first use so app startup never blocks
/// on path_provider. Files live under the app-support dir (not user-visible,
/// survives restarts — the whole point) and are capped so a heavy account
/// doesn't grow the cache without bound.
class ChatSnapshotDiskCache {
  ChatSnapshotDiskCache();

  static const _tag = 'ChatSnapshotDiskCache';
  static const _dirName = 'chat_snapshots';

  /// Keep at most this many transcripts on disk; the oldest-written files
  /// are evicted past the cap.
  static const _maxFiles = 60;

  Directory? _dir;

  Future<Directory?> _ensureDir() async {
    if (_dir != null) return _dir;
    try {
      final base = await getApplicationSupportDirectory();
      final d = Directory('${base.path}/$_dirName');
      if (!d.existsSync()) await d.create(recursive: true);
      _dir = d;
      return d;
    } catch (e, st) {
      AppLogger.warn(_tag, 'could not open cache dir', error: e, stackTrace: st);
      return null;
    }
  }

  /// Conversation ids are UUIDs, but sanitise anyway so a stray id can't
  /// escape the cache dir or collide with a path separator.
  String _fileName(String id) =>
      '${id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}.json';

  /// Reads the raw JSON body for [id], or null when nothing's cached.
  Future<String?> readBody(String id) async {
    final dir = await _ensureDir();
    if (dir == null) return null;
    try {
      final f = File('${dir.path}/${_fileName(id)}');
      if (!f.existsSync()) return null;
      return await f.readAsString();
    } catch (e, st) {
      AppLogger.warn(_tag, 'readBody($id) failed', error: e, stackTrace: st);
      return null;
    }
  }

  /// Writes the raw response [body] for [id] verbatim — no decode. Used by
  /// the background prefetch (cheapest possible persist) and by the
  /// interactive fetch path (which re-encodes its decoded map).
  Future<void> writeBody(String id, String body) async {
    final dir = await _ensureDir();
    if (dir == null) return;
    try {
      final f = File('${dir.path}/${_fileName(id)}');
      await f.writeAsString(body, flush: false);
      unawaited(_evictIfNeeded(dir));
    } catch (e, st) {
      AppLogger.warn(_tag, 'writeBody($id) failed', error: e, stackTrace: st);
    }
  }

  /// Convenience for the interactive path, which holds a decoded map.
  Future<void> writeMap(String id, Map<String, dynamic> raw) async {
    try {
      await writeBody(id, jsonEncode(raw));
    } catch (e, st) {
      AppLogger.warn(_tag, 'writeMap($id) failed', error: e, stackTrace: st);
    }
  }

  /// True when [id] has a cached file newer than [maxAge] — lets the
  /// prefetch skip conversations that were just persisted.
  Future<bool> isFresh(String id, Duration maxAge) async {
    final dir = await _ensureDir();
    if (dir == null) return false;
    try {
      final f = File('${dir.path}/${_fileName(id)}');
      if (!f.existsSync()) return false;
      final age = DateTime.now().difference(f.statSync().modified);
      return age <= maxAge;
    } catch (_) {
      return false;
    }
  }

  /// Deletes every cached transcript. Call on sign-out / account deletion.
  Future<void> clear() async {
    final dir = _dir ?? await _ensureDir();
    if (dir == null) return;
    try {
      if (dir.existsSync()) await dir.delete(recursive: true);
      _dir = null;
    } catch (e, st) {
      AppLogger.warn(_tag, 'clear() failed', error: e, stackTrace: st);
    }
  }

  /// Bounds the cache: when over [_maxFiles], delete the oldest-modified
  /// files until back under the cap. Best-effort; failures only log.
  Future<void> _evictIfNeeded(Directory dir) async {
    try {
      final files = <File>[
        for (final e in dir.listSync())
          if (e is File && e.path.endsWith('.json')) e,
      ];
      if (files.length <= _maxFiles) return;
      files.sort(
          (a, b) => a.statSync().modified.compareTo(b.statSync().modified));
      for (final f in files.take(files.length - _maxFiles)) {
        try {
          await f.delete();
        } catch (_) {}
      }
    } catch (_) {
      // ignore — eviction is best-effort
    }
  }
}
