# Mobile (Flutter) — Google + Apple sign-in

The Saqqar backend already accepts both providers. The app's only job is to run
the native sign-in, get an **ID token**, and POST it to Saqqar, which returns the
same bearer token the email/OTP login returns.

## Backend contract (already live)

```
POST https://saqqaar.com/api/v1/auth/google/    { "id_token": "<google id token>" }
POST https://saqqaar.com/api/v1/auth/apple/     { "id_token": "<apple id token>",
                                                  "user": { "first_name": "...", "last_name": "..." } }  // user optional, first Apple sign-in only
```
Both return:
```jsonc
{ "ok": true, "token": "<saqqar bearer token>", "user": {...}, "created": true|false }
```
Store `token` and send it as `Authorization: Bearer <token>` on every other call —
identical to how the email/OTP token is already used. 401 = verification failed.

Auto-link by verified email is built in: signing in with Google or Apple using an
email that already has a Saqqar account logs into that same account.

---

## 1. Google Sign-In

### Packages
```yaml
dependencies:
  google_sign_in: ^6.2.1
  http: ^1.2.0
  flutter_secure_storage: ^9.0.0
```

### Google Cloud Console (one-time, per platform)
In the **same project** as the existing Web client ID
(`487560580263-…apps.googleusercontent.com`):
- **Android OAuth client**: package name + **SHA-1** of your signing keys.
  Get SHA-1: `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android` (debug) and your release keystore for production. Add both.
- **iOS OAuth client**: your iOS bundle ID. Add the reversed client ID to
  `ios/Runner/Info.plist` URL schemes.

### The audience trick (so the backend accepts it with no extra config)
Pass **`serverClientId` = the Web client ID**. Then the ID token's `aud` is the
Web client ID, which the backend already trusts — nothing to add server-side.

```dart
final googleSignIn = GoogleSignIn(
  serverClientId: '487560580263-…apps.googleusercontent.com', // the WEB client ID
  scopes: ['email', 'profile'],
);

Future<String?> googleIdToken() async {
  final account = await googleSignIn.signIn();          // opens the Google picker
  if (account == null) return null;                     // user cancelled
  final auth = await account.authentication;
  return auth.idToken;                                  // <-- send this
}
```

### Exchange for a Saqqar token
```dart
Future<String?> saqqarLoginWithGoogle() async {
  final idToken = await googleIdToken();
  if (idToken == null) return null;
  final resp = await http.post(
    Uri.parse('https://saqqaar.com/api/v1/auth/google/'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'id_token': idToken}),
  );
  if (resp.statusCode >= 400) return null;              // show an error
  return jsonDecode(resp.body)['token'] as String;      // store it
}
```

> If you'd rather NOT use `serverClientId`, add the Android + iOS Google client
> IDs to **Saqqar → /settings/google/ → Mobile client IDs** so their `aud`
> values are accepted. `serverClientId` is simpler — prefer it.

---

## 2. Sign in with Apple (iOS)

Apple sign-in on mobile is native to **iOS** (do Google-only on Android, or use
the web flow for Apple on Android — see note at the end).

### Package
```yaml
dependencies:
  sign_in_with_apple: ^6.1.0
```

### Xcode / Apple Developer (one-time)
- The iOS app's **bundle identifier must be an App ID that has the “Sign in with
  Apple” capability** (you already have the App ID `com.saqqar.ai.web` set as the
  Sign-in-with-Apple **primary**). Either ship the app under that bundle ID, or
  create a proper app App ID, enable Sign in with Apple on it, and **group it**
  with the primary.
- In Xcode → Runner target → **Signing & Capabilities → + Capability → Sign in
  with Apple**.

### The audience note
For **native** Sign in with Apple the ID token's `aud` = the **app's bundle ID**
(NOT the web Services ID). Add that bundle ID to
**Saqqar → /settings/apple/ → Native app IDs**. `com.saqqar.ai.web` is already
there — if the app ships under a different bundle ID, add that one too.

### Code
```dart
Future<String?> saqqarLoginWithApple() async {
  final cred = await SignInWithApple.getAppleIDCredential(
    scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
  );
  final idToken = cred.identityToken;                   // <-- send this
  if (idToken == null) return null;
  final body = {
    'id_token': idToken,
    if (cred.givenName != null || cred.familyName != null)  // only on first sign-in
      'user': {'first_name': cred.givenName ?? '', 'last_name': cred.familyName ?? ''},
  };
  final resp = await http.post(
    Uri.parse('https://saqqaar.com/api/v1/auth/apple/'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(body),
  );
  if (resp.statusCode >= 400) return null;
  return jsonDecode(resp.body)['token'] as String;
}
```
Apple sends the user's name **only on the very first sign-in** — capture it then
(as above); it's blank on later sign-ins, which is fine.

---

## 3. Store + use the token

```dart
final storage = FlutterSecureStorage();
await storage.write(key: 'saqqar_token', value: token);
// every API call:
headers['Authorization'] = 'Bearer ${await storage.read(key: 'saqqar_token')}';
```
This is the exact same token type your email/OTP login already stores — reuse
that code path.

## 4. UI / App Store rules
- Show a "Sign in with Google" and, on iOS, a "Sign in with Apple" button.
- **App Store Review Guideline 4.8**: because the iOS app offers Google (a
  third-party login), it **must** also offer Sign in with Apple. You're covered.
- Follow each brand's button guidelines (Google button style; Apple black/white
  button) — same as the web.

## 5. Backend settings to double-check (Saqqar admin UI)
- **/settings/google/** → *Mobile client IDs*: only needed if you DON'T use
  `serverClientId`. With `serverClientId` = the web client ID, leave it empty.
- **/settings/apple/** → *Native app IDs*: must contain the iOS app's bundle ID
  (currently `com.saqqar.ai.web`).

## Apple on Android (optional)
`sign_in_with_apple` supports Android via `WebAuthenticationOptions` using the
**Services ID** (`com.saqqar.ai.signin`) and a redirect URI that bounces the code
back to the app. It's more involved; most apps ship Apple on iOS only and Google
on both. Ask if you want the Android-Apple path detailed.
