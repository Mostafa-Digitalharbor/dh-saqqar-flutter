import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _kAccessTokenKey = 'saqqar.auth.access';
const _kRefreshTokenKey = 'saqqar.auth.refresh';

/// Wraps [FlutterSecureStorage] with tokens stored in OS keychain (iOS)
/// and EncryptedSharedPreferences (Android).
///
/// All accessors are async — never cache the result in a long-lived field
/// without invalidating it on logout.
///
/// DI: provided once at app boot via `RepositoryProvider<SecureTokenStore>`
/// in `main.dart`. Tests provide an in-memory fake instead.
class SecureTokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _aOptions = AndroidOptions(encryptedSharedPreferences: true);
  static const _iOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock,
  );

  Future<void> writeAccessToken(String token) => _storage.write(
        key: _kAccessTokenKey,
        value: token,
        aOptions: _aOptions,
        iOptions: _iOptions,
      );

  Future<void> writeRefreshToken(String token) => _storage.write(
        key: _kRefreshTokenKey,
        value: token,
        aOptions: _aOptions,
        iOptions: _iOptions,
      );

  Future<String?> readAccessToken() => _storage.read(
        key: _kAccessTokenKey,
        aOptions: _aOptions,
        iOptions: _iOptions,
      );

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
  }
}
