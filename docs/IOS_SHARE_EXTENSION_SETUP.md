# iOS Share Extension — "Share → Saqqar" complete setup guide

> **This is one piece of the iOS-native work.** For the full list of everything
> that needs a Mac/Xcode/Apple account (push notifications/APNs, capabilities,
> signing, CocoaPods, `permission_handler` Podfile config), see the master doc
> **`IOS_NATIVE_SETUP.md`** — it links back here for this Share-Extension piece.

> **Read this fully — it is self-contained.** It documents the problem, what
> is **already done in the repo** (Windows side), and **every remaining step
> that must run on a Mac with Xcode**. Hand this file to whoever finishes the
> iOS work; they should not need any other context.

---

## 0) TL;DR

- **Symptom:** On Android, sharing a photo/file from WhatsApp (or anywhere)
  shows **Saqqar** in the system share sheet. On **iOS, Saqqar does not
  appear** in the share sheet.
- **Root cause:** iOS only lists apps that ship a **Share Extension** target.
  The project never had one. (Android works via `<intent-filter>` in the
  manifest; iOS needs a native app-extension target — `receive_sharing_intent`
  cannot create it for you.)
- **Fix:** Add a Share Extension target in Xcode and wire it to a shared
  **App Group**. The Flutter/Dart side is **already complete** — no Dart
  changes are needed.
- **Where the work splits:** everything that can be done as plain files is
  **already committed on the branch** (see §2). The rest is **Xcode/Mac
  only** (see §3) — it needs a Mac, Xcode, and an Apple Developer account
  with the App Group registered.

**Key identifiers (use these verbatim):**

| Thing | Value |
|---|---|
| Host app bundle id | `sa.com.digitalharbor.saqqar` |
| App Group id | `group.sa.com.digitalharbor.saqqar` |
| Share Extension target name | `Share Extension` (use this exact name) |
| Redirect URL scheme | `ShareMedia-sa.com.digitalharbor.saqqar` |

---

## 1) Why Android works and iOS doesn't

**Android** — `android/app/src/main/AndroidManifest.xml` declares
`ACTION_SEND` / `ACTION_SEND_MULTIPLE` intent-filters for images, PDF, Office
docs, and CSV (lines ~50–79). The OS reads these and lists Saqqar in the
share sheet. `receive_sharing_intent` auto-injects this on Android.

**iOS** — there is **no equivalent in Info.plist**. The only way for an app
to appear in the iOS share sheet is to ship a **Share Extension** (a separate
bundled target with its own bundle id, `NSExtension` activation rules, and
code). The extension receives the shared items, writes them into a shared
**App Group** container, then opens the host app (via a custom URL scheme) so
the Flutter plugin can read them. None of this existed in the project.

---

## 2) ✅ Already done in this branch (Windows side — nothing to redo)

These files are committed. The Mac work in §3 mostly consists of *adding them
to an Xcode target* and *toggling capabilities* — not authoring them.

| File | Purpose |
|---|---|
| `ios/Share Extension/ShareViewController.swift` | The extension's controller. Subclasses the plugin's `RSIShareViewController`; `shouldAutoRedirect()` returns `true` so picking Saqqar jumps straight into the app. |
| `ios/Share Extension/Info.plist` | `NSExtension` config + activation rules (images/files/text, multi-select up to 20). References `MainInterface` storyboard. |
| `ios/Share Extension/MainInterface.storyboard` | Minimal storyboard whose root VC custom class is `ShareViewController`, `customModuleProvider="target"` (resolves to whatever module the target compiles as — no hard-coded module name). Transparent background so the auto-redirect doesn't flash. |
| `ios/Share Extension/ShareExtension.entitlements` | App Group `group.sa.com.digitalharbor.saqqar` for the extension target. |
| `ios/Runner/Runner.entitlements` | Same App Group for the host app. |
| `ios/Runner/Info.plist` (edited) | Adds `CFBundleURLTypes`: the `ShareMedia-$(PRODUCT_BUNDLE_IDENTIFIER)` redirect scheme (required for hand-off) **and** the `saqqar` deep-link scheme. |

**Dart side (already wired, do NOT change):**
`receive_sharing_intent` is in `pubspec.yaml`. `lib/.../share_intent_bootstrap.dart`
listens via `ReceiveSharingIntent.instance.getMediaStream()` /
`getInitialMedia()` and stages files into `ShareIntakeService`; the chat
destination sheet then routes them to the chosen conversation. This pipeline
is platform-agnostic and already works on Android — once the iOS extension
stages files into the App Group, the same Dart code receives them.

---

## 3) ⛏️ Remaining steps — **Mac + Xcode only**

> Prerequisite: a Mac with Xcode, CocoaPods, Flutter, and an Apple Developer
> account/team that can register App Groups. Run `flutter pub get` first so
> `ios/.symlinks/plugins/` and the Podfile exist.

### 3.1 Create the Share Extension target
1. Open **`ios/Runner.xcworkspace`** in Xcode (the *workspace*, not the
   project).
2. **File → New → Target… → iOS → Share Extension → Next.**
3. **Product Name:** `Share Extension` (exact — matches the repo folder).
   **Language:** Swift. **Finish.** If asked "Activate scheme?", **Activate**.
4. Xcode creates a `Share Extension` group with its own
   `ShareViewController.swift`, `Info.plist`, and `MainInterface.storyboard`.

### 3.2 Replace the generated files with the repo's files
The repo already has correct versions under `ios/Share Extension/`. Replace
the generated ones so you don't have to re-author them:

1. In Xcode, **delete** (Move to Trash) the generated
   `ShareViewController.swift` and `Info.plist` from the `Share Extension`
   group. You may keep or delete the generated `MainInterface.storyboard`
   (the repo ships one too — keep a single copy).
2. **Add Files to "Runner"…** → select the repo's
   `ios/Share Extension/ShareViewController.swift`,
   `ios/Share Extension/Info.plist`,
   `ios/Share Extension/MainInterface.storyboard` →
   **Target: ✔ Share Extension** (only). Uncheck Runner.
3. Select the **Share Extension** target → **Build Settings** →
   set **Info.plist File** to `Share Extension/Info.plist`.
4. Confirm **Build Phases → Compile Sources** includes
   `ShareViewController.swift`, and **Copy Bundle Resources** includes
   `MainInterface.storyboard`.

> If you instead keep Xcode's generated `ShareViewController.swift`, just make
> it `import receive_sharing_intent` and `class ShareViewController:
> RSIShareViewController { override func shouldAutoRedirect() -> Bool { true } }`.

### 3.3 Add the plugin pod to the extension target (Podfile)
The extension compiles `import receive_sharing_intent`, so its pod must be
linked to the extension target. Edit **`ios/Podfile`** — add a target block
next to the existing `target 'Runner' do … end`:

```ruby
target 'Share Extension' do
  inherit! :search_paths
  pod 'receive_sharing_intent', :path => '.symlinks/plugins/receive_sharing_intent/ios'
end
```

Then:

```bash
cd ios
pod install
cd ..
```

> If `pod install` complains the path doesn't exist, run `flutter pub get`
> from the project root first (it creates `ios/.symlinks/plugins/...`).

### 3.4 App Group on BOTH targets — **this is what actually makes it work**
The #1 cause of "still not in the share sheet / app opens but no file": a
missing or mismatched App Group.

1. Select **Runner** target → **Signing & Capabilities** →
   **+ Capability → App Groups** → add **`group.sa.com.digitalharbor.saqqar`**.
   Xcode wires `CODE_SIGN_ENTITLEMENTS` to an entitlements file — point it at
   the repo's **`Runner/Runner.entitlements`** (or let Xcode merge into it).
2. Select **Share Extension** target → **Signing & Capabilities** →
   **+ Capability → App Groups** → add the **same** group. Point its
   `CODE_SIGN_ENTITLEMENTS` at **`Share Extension/ShareExtension.entitlements`**.
3. Both targets must be signed by a **team** that has that App Group
   registered (Apple Developer portal → Identifiers → App Groups). Register
   `group.sa.com.digitalharbor.saqqar` if it isn't already, and enable the
   App Groups capability on both App IDs.

> The group id must be **exactly** `group.` + the host bundle id. If you ever
> change it, change it in: Runner.entitlements, ShareExtension.entitlements,
> and both Xcode capabilities — nowhere else (the plugin derives it from the
> bundle id automatically).

### 3.5 Verify the Runner URL scheme survived
Open **`ios/Runner/Info.plist`** and confirm `CFBundleURLTypes` still contains
`ShareMedia-$(PRODUCT_BUNDLE_IDENTIFIER)` (the repo added it; make sure no
Xcode rewrite dropped it). Without it the extension can't bring the app
forward and no file is delivered.

### 3.6 Version/signing hygiene for the extension
- Set the Share Extension target's **Marketing Version** and **Build** to
  inherit from the project (`$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)`)
  so its version always matches Runner — App Store Connect rejects mismatches.
- Set its **Deployment Target** equal to Runner's.
- Give it a **unique bundle id** Xcode suggests
  (`sa.com.digitalharbor.saqqar.Share-Extension` or similar) — keep it under
  the host id namespace.

### 3.7 Build & test (on a REAL device)
```bash
flutter clean
flutter pub get
cd ios && pod install && cd ..
flutter build ios            # or run the Runner scheme from Xcode
```
1. Install on a **physical iPhone** (Simulator share sheets are unreliable
   for extensions).
2. Open **Photos** → share an image, or **Files** → share a PDF →
   **Saqqar should now be in the share sheet**.
3. Tap Saqqar → the app foregrounds with the file staged in the chat
   composer / destination sheet (existing Dart flow — no code change).

---

## 4) Troubleshooting (most-likely first)

| Symptom | Cause / fix |
|---|---|
| Saqqar not in the share sheet at all | App Group missing or mismatched on one of the two targets, or the signing team doesn't have the group registered. Re-check §3.4. Also delete the app from the device and reinstall (iOS caches extension registrations). |
| App opens but no file arrives | `ShareMedia-<bundle id>` scheme missing from Runner `Info.plist` (§3.5), or the group id differs between the two entitlements. |
| `import receive_sharing_intent` fails to build | Podfile block (§3.3) not added or `pod install` not run for the extension target. |
| Storyboard error / black screen | The storyboard's root VC custom class isn't `ShareViewController`, or `MainInterface` isn't set as `NSExtensionMainStoryboard`. Open the storyboard → Identity inspector → Custom Class = `ShareViewController`. |
| Only images work, not PDFs/CSV | Widen the activation rule in `Share Extension/Info.plist` (`NSExtensionActivationSupportsFileWithMaxCount`). It already allows files + images + text up to 20 items. |
| Upload to App Store Connect rejected | Extension version/build don't match Runner (§3.6). |

---

## 5) Optional: prefer no storyboard (principal-class variant)
If you'd rather not ship a storyboard, replace these two keys in
`Share Extension/Info.plist`:

```xml
<key>NSExtensionMainStoryboard</key>
<string>MainInterface</string>
```
with:
```xml
<key>NSExtensionPrincipalClass</key>
<string>ShareViewController</string>
```
and remove the `MainInterface.storyboard` from the target. `RSIShareViewController`
runs its logic in `viewDidLoad`, which fires either way. Use the storyboard
path (default) unless you have a reason not to — it matches the plugin's
official example.

---

## 6) Acceptance checklist
- [ ] `Share Extension` target exists, signed, with App Group
      `group.sa.com.digitalharbor.saqqar`.
- [ ] Runner target has the **same** App Group.
- [ ] `ShareViewController.swift` subclasses `RSIShareViewController`.
- [ ] `Share Extension/Info.plist` is the target's Info.plist with the
      `NSExtension` activation rules.
- [ ] Podfile has the `Share Extension` target block; `pod install` ran.
- [ ] Runner `Info.plist` keeps the `ShareMedia-<bundle id>` URL scheme.
- [ ] On a real iPhone: WhatsApp/Photos/Files **Share → Saqqar** appears, and
      picking it foregrounds the app with the file staged.
