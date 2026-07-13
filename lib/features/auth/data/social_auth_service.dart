import 'dart:convert';
import 'dart:io' show Platform;

import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../core/logging/app_logger.dart';
import 'social_auth_config.dart';

/// The Google half of a native sign-in — just the ID token the backend needs.
class GoogleSignInResult {
  const GoogleSignInResult({required this.idToken});
  final String idToken;
}

/// The Apple half. Apple returns the user's name ONLY on the very first
/// sign-in, so [firstName] / [lastName] may be null on subsequent ones.
class AppleSignInResult {
  const AppleSignInResult({
    required this.idToken,
    this.firstName,
    this.lastName,
  });
  final String idToken;
  final String? firstName;
  final String? lastName;
}

/// Raised for real sign-in failures (misconfiguration, no token returned).
/// User cancellation is NOT an error — the service returns null for that so
/// the UI can quietly reset instead of showing a toast.
class SocialAuthException implements Exception {
  const SocialAuthException(this.message);
  final String message;
  @override
  String toString() => 'SocialAuthException: $message';
}

/// Wraps the native Google / Apple sign-in SDKs and hands back the provider's
/// ID token. The token exchange for a Saqqar bearer lives in [AuthApi]; this
/// class only owns the platform picker + token extraction.
///
/// See `docs/MOBILE_AUTH_GUIDE.md`. `serverClientId` = the Web client ID makes
/// the Google ID token's `aud` a value the backend already trusts.
class SocialAuthService {
  /// One shared tag so the whole Apple flow is greppable in the console —
  /// tell the tester to copy every line containing `AppleSignIn`.
  static const _appleTag = 'AppleSignIn';

  GoogleSignIn? _google;

  GoogleSignIn get _googleSignIn => _google ??= GoogleSignIn(
        // iOS needs its own client ID passed explicitly; on Android the SDK
        // resolves the app via the package + SHA-1 registered in the Cloud
        // project, so `clientId` stays null there.
        clientId: Platform.isIOS ? SocialAuthConfig.googleIosClientId : null,
        // The Web client ID → the ID token's `aud`, which Saqqar trusts.
        serverClientId: SocialAuthConfig.isGoogleConfigured
            ? SocialAuthConfig.googleServerClientId
            : null,
        scopes: const ['email', 'profile'],
      );

  /// Opens the native Google account picker. Returns null if the user
  /// cancels; throws [SocialAuthException] if unconfigured or no token comes
  /// back.
  Future<GoogleSignInResult?> signInWithGoogle() async {
    if (!SocialAuthConfig.isGoogleConfigured) {
      throw const SocialAuthException(
        'Google sign-in is not configured (missing web serverClientId).',
      );
    }
    // Sign out of any cached session first so the account chooser always
    // appears — otherwise a returning user is silently locked to their last
    // Google account with no way to switch.
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Non-fatal: a failed pre-sign-out just means the picker may reuse the
      // previous account. The sign-in below still proceeds.
    }
    final account = await _googleSignIn.signIn();
    if (account == null) return null; // user dismissed the picker
    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const SocialAuthException('Google returned no ID token.');
    }
    return GoogleSignInResult(idToken: idToken);
  }

  /// Best-effort local Google sign-out. Called on app logout so the next
  /// sign-in starts clean. Swallows errors — logout must never be blocked.
  Future<void> signOutGoogle() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
  }

  /// Runs native Sign in with Apple (iOS). Returns null if the user cancels;
  /// throws on any other failure.
  Future<AppleSignInResult?> signInWithApple() async {
    AppLogger.info(_appleTag, '① requesting Apple ID credential…');
    try {
      final cred = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final idToken = cred.identityToken;
      AppLogger.info(
        _appleTag,
        '② credential received — identityToken len=${idToken?.length ?? 0}, '
        'authCode len=${cred.authorizationCode.length}, '
        'givenName=${cred.givenName != null}, '
        'familyName=${cred.familyName != null}, '
        'email=${cred.email ?? "(null, only on 1st sign-in)"}',
      );
      if (idToken == null || idToken.isEmpty) {
        AppLogger.error(_appleTag, '✗ Apple returned NO identity token');
        throw const SocialAuthException('Apple returned no identity token.');
      }
      _logTokenClaims(idToken);
      return AppleSignInResult(
        idToken: idToken,
        firstName: cred.givenName,
        lastName: cred.familyName,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        AppLogger.info(_appleTag, '⊘ user canceled the Apple sheet — no-op');
        return null;
      }
      AppLogger.error(
        _appleTag,
        '✗ Apple authorization failed — code=${e.code}, message=${e.message}',
      );
      rethrow;
    } catch (e, st) {
      AppLogger.error(
        _appleTag,
        '✗ unexpected error getting Apple credential',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Debug diagnostic: decodes the (UNVERIFIED — display only) JWT payload of
  /// the Apple identity token and logs the claims the backend will check. The
  /// critical one is `aud`: it MUST be present in the backend's
  /// `/settings/apple/` → Native app IDs list, or the exchange returns 401.
  /// Never throws — a malformed token just logs a note.
  void _logTokenClaims(String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length != 3) {
        AppLogger.warn(
          _appleTag,
          '  identity token is not a 3-part JWT (parts=${parts.length})',
        );
        return;
      }
      var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      payload = payload.padRight((payload.length + 3) ~/ 4 * 4, '=');
      final map =
          jsonDecode(utf8.decode(base64.decode(payload))) as Map<String, dynamic>;
      AppLogger.info(
        _appleTag,
        '③ token claims → aud=${map['aud']} | iss=${map['iss']} | '
        'sub=${map['sub']} | exp=${map['exp']} | '
        'email=${map['email'] ?? "(none)"} | '
        'email_verified=${map['email_verified']} | '
        'is_private_email=${map['is_private_email']}',
      );
      AppLogger.info(
        _appleTag,
        '   ⇒ backend MUST list aud "${map['aud']}" under /settings/apple/ '
        'Native app IDs (else 401)',
      );
    } catch (e) {
      AppLogger.warn(_appleTag, '  could not decode token claims: $e');
    }
  }
}
