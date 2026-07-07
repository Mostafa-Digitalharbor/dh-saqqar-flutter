/// OAuth client IDs for native Google / Apple sign-in.
///
/// The Google client IDs live in Google Cloud project `487560580263` — which
/// is deliberately SEPARATE from the Firebase / FCM project (`saqqar-ai`,
/// number `55105284059`). That's fine: this flow uses `google_sign_in`
/// directly and the Saqqar backend verifies the ID token — it does NOT go
/// through Firebase Auth, so the two projects never need to match. See
/// `docs/MOBILE_AUTH_GUIDE.md`.
class SocialAuthConfig {
  SocialAuthConfig._();

  /// **WEB** application client ID, passed to `google_sign_in` as
  /// `serverClientId` so the ID token's `aud` is the web client the Saqqar
  /// backend already trusts (the "audience trick" — guide §1). This is what
  /// makes the token accepted server-side with no extra backend config.
  ///
  /// The `Web application` OAuth client (project 487560580263) — NOT the
  /// Android/iOS clients. A `--dart-define=SAQQAR_GOOGLE_SERVER_CLIENT_ID=…`
  /// still overrides it (e.g. to point a build at a different project).
  static const String googleServerClientId = String.fromEnvironment(
    'SAQQAR_GOOGLE_SERVER_CLIENT_ID',
    defaultValue:
        '487560580263-46d5ktgbplf1iq2kp2p4o9ee4isbk2h7.apps.googleusercontent.com',
  );

  /// iOS OAuth client ID — `google_sign_in` needs it on iOS. Mirrored in
  /// `ios/Runner/Info.plist` as `GIDClientID` and as the reversed-client-id
  /// URL scheme (`com.googleusercontent.apps.<id>`).
  static const String googleIosClientId =
      '487560580263-mteed8gpe4eb525bjtamc5e4328tgqfe.apps.googleusercontent.com';

  /// True once the web `serverClientId` is present. Google sign-in needs it to
  /// return a usable ID token on both platforms, so the button gates on this.
  static bool get isGoogleConfigured => googleServerClientId.isNotEmpty;
}
