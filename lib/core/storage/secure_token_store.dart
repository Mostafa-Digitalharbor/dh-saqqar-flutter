import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _kAccessTokenKey = 'saqqar.auth.access';
const _kRefreshTokenKey = 'saqqar.auth.refresh';

/// Wraps [FlutterSecureStorage] with tokens stored in OS keychain (iOS)
/// and EncryptedSharedPreferences (Android).
///
/// The access token is mirrored into a short-lived in-memory field so the
/// hot path (the [AuthInterceptor] attaching a bearer to EVERY request,
/// including the 1.5 s chat poll + concurrent attachment/approval pollers)
/// doesn't pay a Keychain / EncryptedSharedPreferences decrypt each time.
/// The mirror is the reason the old "never cache the result" warning is
/// gone: it's invalidated in lock-step with every [writeAccessToken] /
/// [clear], which are the ONLY mutation paths (all writes go through this
/// class — verified across `auth_cubit` + `auth_interceptor`), so a stale
/// read is impossible. Refresh token is not cached (never read on the hot
/// path — there is no refresh flow per spec).
///
/// DI: provided once at app boot via `RepositoryProvider<SecureTokenStore>`
/// in `main.dart`. Tests provide an in-memory fake instead.
class SecureTokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _aOptions = AndroidOptions(encryptedSharedPreferences: true);
  static const _iOptions = IOSOptions(
    // `first_unlock_this_device` = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly.
    // Still readable after the first unlock post-boot (so the background
    // pollers + FCM isolate can attach the bearer with the screen locked —
    // unchanged behaviour), but the `ThisDeviceOnly` variant keeps the item
    // OUT of encrypted iTunes/Finder + iCloud backups, so a restored backup
    // can't carry the live token/credentials onto a different device.
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );

  /// In-memory mirror of the access token. `null` while unknown OR when the
  /// user is signed out — [_accessLoaded] disambiguates the two so a genuine
  /// "no token" state isn't re-read from secure storage on every request.
  String? _cachedAccess;
  bool _accessLoaded = false;

  Future<void> writeAccessToken(String token) async {
    await _storage.write(
      key: _kAccessTokenKey,
      value: token,
      aOptions: _aOptions,
      iOptions: _iOptions,
    );
    _cachedAccess = token;
    _accessLoaded = true;
  }

  Future<void> writeRefreshToken(String token) => _storage.write(
    key: _kRefreshTokenKey,
    value: token,
    aOptions: _aOptions,
    iOptions: _iOptions,
  );

  Future<String?> readAccessToken() async {
    if (_accessLoaded) return _cachedAccess;
    final token = await _storage.read(
      key: _kAccessTokenKey,
      aOptions: _aOptions,
      iOptions: _iOptions,
    );
    _cachedAccess = token;
    _accessLoaded = true;
    return token;
  }

  Future<String?> readRefreshToken() => _storage.read(
    key: _kRefreshTokenKey,
    aOptions: _aOptions,
    iOptions: _iOptions,
  );

  Future<void> clear() async {
    await _storage.delete(
      key: _kAccessTokenKey,
      aOptions: _aOptions,
      iOptions: _iOptions,
    );
    await _storage.delete(
      key: _kRefreshTokenKey,
      aOptions: _aOptions,
      iOptions: _iOptions,
    );
    // Keep the mirror consistent: token is now definitively absent (loaded,
    // null) so the next read short-circuits instead of hitting storage.
    _cachedAccess = null;
    _accessLoaded = true;
  }
}
