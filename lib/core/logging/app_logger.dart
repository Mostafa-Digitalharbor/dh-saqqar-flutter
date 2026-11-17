import 'package:flutter/foundation.dart';

/// Severity of a log entry. Maps to a single-character prefix in the
/// console output so eyeballing the log column is fast — `[I]` info,
/// `[W]` warn, `[E]` error.
enum LogLevel {
  debug('D'),
  info('I'),
  warn('W'),
  error('E');

  const LogLevel(this.tag);
  final String tag;
}

/// Centralized ad-hoc logger for cubits / services / anything that's not
/// a Dio request (Dio goes through [LoggingInterceptor]) and not a Cubit
/// state transition (those go through [AppBlocObserver]).
///
/// Usage:
/// ```dart
/// AppLogger.info('VaultCubit', 'loading projects…');
/// AppLogger.warn('AuthCubit', 'token validation failed', error: e);
/// AppLogger.error('UploadService', 'attachment 24MB rejected', error: err, stackTrace: st);
/// ```
///
/// Output (debug-only — release builds are no-ops):
/// ```
/// [I] VaultCubit · loading projects…
/// [W] AuthCubit · token validation failed
///     ↳ ApiException(401, Not authenticated.)
/// [E] UploadService · attachment 24MB rejected
///     ↳ FormatException: invalid mime
///     ↳ #0 …
/// ```
///
/// Designed for grep-ability — the tag is always first after the level,
/// the message is always after a `·` separator, and error/stack chunks
/// are indented under the originating line.
/// Signature for a release-mode crash reporter hook. Receives every
/// `AppLogger.warn` / `AppLogger.error` call so it can forward them to
/// Sentry / Firebase Crashlytics / Bugsnag — without coupling the rest
/// of the app to a specific provider.
typedef CrashReporter =
    void Function(
      LogLevel level,
      String tag,
      String message, {
      Object? error,
      StackTrace? stackTrace,
    });

class AppLogger {
  AppLogger._();

  /// Smallest level that actually prints. Defaults to debug. Tests can
  /// raise it via [setMinLevel] to keep noise out of test logs.
  static LogLevel _minLevel = LogLevel.debug;

  /// Optional sink for release-mode crash reporting. When set, every
  /// `warn` and `error` call forwards to the reporter ON TOP OF the
  /// console output (debug-only). Wire from `main.dart`:
  ///
  /// ```dart
  /// AppLogger.setCrashReporter((level, tag, msg, {error, stackTrace}) {
  ///   FirebaseCrashlytics.instance.recordError(error ?? msg, stackTrace);
  /// });
  /// ```
  static CrashReporter? _crashReporter;

  static void setMinLevel(LogLevel level) => _minLevel = level;

  /// Installs (or clears, with `null`) the global crash reporter sink.
  /// Idempotent — re-call to swap providers at runtime.
  static void setCrashReporter(CrashReporter? reporter) {
    _crashReporter = reporter;
  }

  static void debug(String tag, String message) =>
      _log(LogLevel.debug, tag, message);

  static void info(String tag, String message) =>
      _log(LogLevel.info, tag, message);

  static void warn(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) => _log(LogLevel.warn, tag, message, error: error, stackTrace: stackTrace);

  static void error(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) =>
      _log(LogLevel.error, tag, message, error: error, stackTrace: stackTrace);

  static void _log(
    LogLevel level,
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    // Forward warn/error to the crash reporter (if installed) in BOTH
    // debug and release builds — that's the whole point of having it.
    // The debug console print is debug-only.
    final reporter = _crashReporter;
    if (reporter != null &&
        (level == LogLevel.warn || level == LogLevel.error)) {
      try {
        reporter(level, tag, message, error: error, stackTrace: stackTrace);
      } catch (_) {
        // A crashing crash reporter must not bring the app down.
      }
    }

    if (!kDebugMode) return;
    if (level.index < _minLevel.index) return;

    final buf = StringBuffer('[${level.tag}] $tag · $message');
    if (error != null) {
      buf.write('\n    ↳ $error');
    }
    if (stackTrace != null) {
      final shortened = _shortenStack(stackTrace.toString());
      if (shortened.isNotEmpty) buf.write('\n    $shortened');
    }
    debugPrint(buf.toString());
  }

  /// Keep stack traces actionable — first 6 frames is usually enough to
  /// locate the offending call site; anything deeper just clutters logs.
  static String _shortenStack(String raw) {
    final lines = raw.split('\n');
    if (lines.length <= 6) return raw;
    return [
      ...lines.take(6),
      '    … ${lines.length - 6} more frames',
    ].join('\n    ');
  }
}
