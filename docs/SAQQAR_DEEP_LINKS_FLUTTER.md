# Saqqar — make `saqqaar.com` links open the app (Flutter)

**For:** the Saqqar mobile developer
**Stack:** Flutter (iOS + Android)
**Goal:** when a user who has the Saqqar app installed **taps** a
`https://saqqaar.com/...` link, the **app** opens on the matching screen. If the
app is not installed, the link opens in the browser (automatic — nothing to do).

> ⚠️ **iOS note:** *typing* `saqqaar.com` in the Safari address bar will **not**
> open the app — Apple only routes **tapped** links to apps. That is expected and
> not a bug. (For the typed case we may add a Safari "Open in app" banner later.)

---

## 0. What is already done (server side — you don't touch this)

The backend team has published and **verified** both domain-association files:

| Platform | URL | Status |
|---|---|---|
| iOS | `https://saqqaar.com/.well-known/apple-app-site-association` | ✅ live, `application/json`, no redirect |
| Android | `https://saqqaar.com/.well-known/assetlinks.json` | ✅ live, verified by Google Digital Asset Links API |

Your job is **only the app-side changes** below. The links will not open the app
until a build with these changes is shipped.

### Identifiers already registered in those files (must match your build exactly)

| | Value |
|---|---|
| Apple **Team ID** | `P95FNYY2S2` |
| iOS **bundle id** | `sa.com.digitalharbor.saqqarapp` |
| iOS AppID in AASA | `P95FNYY2S2.sa.com.digitalharbor.saqqarapp` |
| Android **applicationId** | `sa.com.digitalharbor.saqqar` |
| Android signing **SHA-256** | `B6:93:48:AC:DC:C5:1B:F0:AC:6C:2F:FD:4F:BF:C2:76:F2:E9:9D:C4:BF:E8:77:52:CF:B3:67:BC:7B:20:D4:B1` |

> The iOS bundle ends in **`saqqarapp`**, the Android package does **not** (`...saqqar`).
> That is intentional — ship under exactly these. If either identifier changes,
> tell the backend team so they update the association files.

---

## 1. iOS — Associated Domains

### a) Xcode / Apple Developer portal
- In the Apple Developer portal, on App ID `sa.com.digitalharbor.saqqarapp`,
  enable the **Associated Domains** capability.
- In Xcode: target **Runner → Signing & Capabilities → + Capability →
  Associated Domains**.

### b) `ios/Runner/Runner.entitlements`
```xml
<key>com.apple.developer.associated-domains</key>
<array>
  <string>applinks:saqqaar.com</string>
</array>
```

That's it for iOS platform config — routing is handled in Dart (§3).

---

## 2. Android — verified App Links intent-filter

In `android/app/src/main/AndroidManifest.xml`, inside the **main launcher
`<activity>`** (usually `.MainActivity`), add:

```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="https" android:host="saqqaar.com" />
</intent-filter>
```

- Keep the existing `saqqar://` scheme filter (push notifications use it) — add
  this **https** filter alongside it, don't replace it.
- `android:autoVerify="true"` makes Android fetch `assetlinks.json` and open the
  app **without** the "open with" chooser. It works because the signing SHA-256
  above is already published.
- Make sure the release build is signed with the key whose SHA-256 is listed above
  (Play App Signing key). If you also test with a different debug/upload key, its
  SHA-256 must be added to `assetlinks.json` too — tell the backend team.

---

## 3. Flutter — receive the link and route it

Use [`app_links`](https://pub.dev/packages/app_links) (handles both platforms,
cold start + running). If you already use `go_router` / `uni_links`, keep your
existing setup and just map the paths in the table below.

`pubspec.yaml`:
```yaml
dependencies:
  app_links: ^6.3.0
```

Handle both the **initial** link (app launched by the link) and the **stream**
(link received while the app is running):

```dart
import 'package:app_links/app_links.dart';

final _appLinks = AppLinks();

Future<void> initDeepLinks() async {
  // Cold start: app was opened by tapping a link
  final initial = await _appLinks.getInitialLink();
  if (initial != null) _handleUri(initial);

  // Running / background: links arriving later
  _appLinks.uriLinkStream.listen(_handleUri);
}

void _handleUri(Uri uri) {
  // https links from saqqaar.com AND the existing saqqar:// push scheme
  // both land here.
  if (uri.host == 'saqqaar.com' || uri.scheme == 'saqqar') {
    _routeToScreen(uri);
  }
}
```

### Path → screen mapping

Route the incoming `https://saqqaar.com/<path>` to the **same screens** your
existing `saqqar://` deep links already use. At minimum:

| Incoming link | Screen |
|---|---|
| `https://saqqaar.com/` | Home / conversations list |
| `https://saqqaar.com/new` | New conversation |
| `https://saqqaar.com/chats/<id>` | Conversation `<id>` (same as `saqqar://chats/<id>`) |
| `https://saqqaar.com/share/<token>` | Shared conversation view |
| anything else | Home (safe default) |

```dart
void _routeToScreen(Uri uri) {
  final segs = uri.pathSegments; // path segments, scheme-independent
  if (segs.isEmpty) { navigateHome(); return; }
  switch (segs.first) {
    case 'chats':
      if (segs.length > 1) { openConversation(segs[1]); return; }
      break;
    case 'new':
      openNewConversation(); return;
    case 'share':
      if (segs.length > 1) { openSharedConversation(segs[1]); return; }
      break;
  }
  navigateHome();
}
```

> The `saqqar://chats/<id>` push deep link and `https://saqqaar.com/chats/<id>`
> both produce `pathSegments == ['chats', '<id>']`, so a single handler covers both.

---

## 4. Paths that intentionally do NOT open the app

The iOS association file excludes these (they stay in the browser); mirror the
same intent on Android by not deep-linking them:

`/auth/*` (OAuth callbacks — **must** stay in browser or sign-in breaks),
`/excel-addin/*`, `/settings/*`, `/admin/*`, `/static/*`, `/media/*`,
`/privacy`, `/terms`, `/support`, `/refund`, `/cancellation`.

Everything else opens the app.

---

## 5. Test end to end

### iOS (real device, app installed)
- Send yourself `https://saqqaar.com/new` in Notes/Messages and **tap** it →
  app opens on New conversation.
- Tap `https://saqqaar.com/privacy` → stays in Safari.
- Apple validator: https://search.developer.apple.com/appsearch-validation-tool/
  (enter `saqqaar.com`).

### Android (device/emulator, app installed)
```bash
# Force re-verification of the App Link
adb shell pm verify-app-links --re-verify sa.com.digitalharbor.saqqar
# Check it verified
adb shell pm get-app-links sa.com.digitalharbor.saqqar   # expect: saqqaar.com  verified
# Simulate a tapped link
adb shell am start -a android.intent.action.VIEW -d "https://saqqaar.com/new"
```
App should open directly (no chooser).

---

## 6. Checklist

- [ ] iOS: Associated Domains enabled on App ID `sa.com.digitalharbor.saqqarapp`
- [ ] iOS: `applinks:saqqaar.com` in `Runner.entitlements`
- [ ] Android: `https`/`saqqaar.com` intent-filter with `autoVerify="true"` added
      (existing `saqqar://` filter kept)
- [ ] Android: release signed with the key matching the published SHA-256
- [ ] Flutter: `app_links` wired for initial + stream links
- [ ] Path routing maps `/`, `/new`, `/chats/<id>`, `/share/<token>`
- [ ] Tested on real iOS + Android devices
- [ ] New builds submitted to App Store / Play Store

Questions on the server side (association files, identifiers, path scope) → back to
the backend team. Everything above is app-side and owned by mobile.
