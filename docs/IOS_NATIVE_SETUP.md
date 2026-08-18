# iOS Native Setup — everything that needs a Mac, Xcode, or an Apple account

> **Read this fully — it is self-contained.** It is the master checklist of
> every iOS-native thing that **cannot be done from the Windows machine** the
> app is being developed on. The Dart/Flutter side (pubspec deps, Info.plist
> strings, `firebase_options.dart`, the Share-Extension source files) is
> **already committed in the repo**. What remains is Xcode capabilities,
> CocoaPods, Apple Developer portal registration, signing, and two config
> files that Apple/Firebase only hand out per-account.
>
> Hand this file (and the companion `IOS_SHARE_EXTENSION_SETUP.md`) to whoever
> finishes the iOS work on a Mac. They should not need any other context.
>
> **Scope split:** anything that is plain files lives in the repo already
> (✅). Anything marked ⛏️ **needs a Mac + Xcode + an Apple Developer
> account/team** and cannot be produced on Windows.

---

## 0) Key identifiers (use these verbatim)

| Thing | Value |
|---|---|
| Host app bundle id | `sa.com.digitalharbor.saqqar` |
| iOS deployment target | `15.0` (set in the Xcode project, Podfile and AppFrameworkInfo.plist) |
| Firebase project id | `saqqar-ai` |
| Firebase iOS app id | `1:55105284059:ios:8518bc677c9023356ca9fe` |
| FCM sender id | `55105284059` |
| App Group id (Share Extension) | `group.sa.com.digitalharbor.saqqar` |
| Deep-link URL scheme | `saqqar` (e.g. `saqqar://chats/<id>`) |
| Share redirect URL scheme | `ShareMedia-sa.com.digitalharbor.saqqar` |

---

## 1) What works on iOS *today* with no Mac action (already in the repo)

These are done as plain files and committed. **Do not redo them** — just make
sure Xcode doesn't silently drop them when it re-writes project files.

| Capability | Plugin | What's already in place |
|---|---|---|
| **Face ID app lock** | `local_auth` | `NSFaceIDUsageDescription` in `ios/Runner/Info.plist`. Touch ID + passcode fallback need no extra key. **No Xcode capability required.** ✅ |
| **Microphone (voice→text)** | `record` / `permission_handler` | `NSMicrophoneUsageDescription` in Info.plist. (See §6 for the one Podfile tweak that hardens the App Store submission.) |
| **Photo / file attach** | `file_picker` | `NSPhotoLibraryUsageDescription` in Info.plist. The picker is a system UI; no extra capability. ✅ |
| **Camera / Location strings** | `permission_handler` (linked, not used) | `NSCameraUsageDescription` + `NSLocationWhenInUseUsageDescription` added defensively so Apple's static check (ITMS-90683) passes. The app never prompts for them at runtime. ✅ |
| **Outbound share** | `share_plus` | Uses the system share sheet — no config. ✅ |
| **Deep links** | custom URL scheme | `CFBundleURLTypes` in Info.plist registers `saqqar` **and** `ShareMedia-<bundle id>`. ✅ |
| **Artifact download/open** | `path_provider` + `open_filex` | App-documents dir needs no permission. ✅ |

> ⚠️ When you open the project in Xcode and toggle capabilities, Xcode rewrites
> `Info.plist` and the entitlements files. **After any capability change,
> re-open `ios/Runner/Info.plist` and confirm all five usage-description keys
> and both `CFBundleURLTypes` entries above still exist.** Losing the
> `ShareMedia-…` scheme silently breaks Share→Saqqar; losing a usage string
> gets the build rejected at upload.

---

## 2) ⛏️ Push notifications (FCM / APNs) — **the biggest Mac-only block**

The Dart side is wired (`firebase_core`, `firebase_messaging`,
`flutter_local_notifications` are in `pubspec.yaml`; `firebase_options.dart`
exists; the device-token contract is `docs/PUSH_NOTIFICATIONS_BACKEND.md`).
iOS push **will not deliver a single notification** until all of the following
are done on a Mac / in the Apple + Firebase consoles. There is no Windows
substitute for any of them.

### 2.0 ✅ Release entitlements — already fixed on 2026-08-10, do not undo

**All three build configurations used to point at `Runner.entitlements`, which
declares `aps-environment: development`.** That is right for a debug build
against the APNs sandbox and wrong for anything you upload: a TestFlight or
App Store build carrying the development entitlement registers with the
sandbox while the server pushes to production, so tokens are rejected and
**not one notification arrives** — with nothing failing at build time to say
so.

Fixed by splitting the file:

| Configuration | Entitlements | `aps-environment` |
|---|---|---|
| Debug | `Runner/Runner.entitlements` | `development` |
| Profile | `Runner/Runner.entitlements` | `development` |
| **Release** | **`Runner/RunnerRelease.entitlements`** | **`production`** |

`RunnerRelease.entitlements` also carries the associated domain, Sign in with
Apple, and the `group.sa.com.digitalharbor.saqqar` app group (needed by the
Share Extension) — so it is a superset, not a replacement to trim.

**On the Mac:** when you enable capabilities in Xcode (§3 below), Xcode may
offer to "fix" the Release entitlements back to `development`. **Decline it.**
If Xcode has already rewritten the file, restore `production` before archiving.

> `Runner/RunnerProfile.entitlements` exists on disk but is referenced by no
> build configuration. It is dead; ignore it, or delete it.

### 2.1 `GoogleService-Info.plist` (iOS) — present, verify it survived

It **is** in the repo at `ios/Runner/GoogleService-Info.plist` (verified
2026-08-10). Earlier revisions of this document said it was missing; that is
no longer true.

What still needs checking on the Mac: the file must be a member of the
**Runner** target and appear in **Build Phases → Copy Bundle Resources**. A
file present on disk but not in the target still throws at
`Firebase.initializeApp()`.

If it is missing or wrong for your Firebase project, re-download it:

1. Firebase Console → project **`saqqar-ai`** → Project settings → your apps
   → the **iOS app** with bundle id `sa.com.digitalharbor.saqqar`
   (app id `1:55105284059:ios:8518bc677c9023356ca9fe`). If the iOS app
   doesn't exist yet, **Add app → iOS** with that exact bundle id.
2. **Download `GoogleService-Info.plist`.**
3. In Xcode, drag it into the **`Runner`** group (next to `Info.plist`) →
   **Target: ✔ Runner**, **Copy items if needed**. It must end up in
   **Build Phases → Copy Bundle Resources** of the Runner target.
4. Place the file at `ios/Runner/GoogleService-Info.plist`. *(It is normally
   git-ignored as a secret — keep it out of public source control, but it must
   be on disk for every build.)*

### 2.2 Enable the **Push Notifications** capability
Xcode → select **Runner** target → **Signing & Capabilities** →
**+ Capability → Push Notifications**. This adds `aps-environment` to
`Runner.entitlements` and is what lets iOS issue an APNs token at all.

### 2.3 Enable **Background Modes → Remote notifications**
Same screen → **+ Capability → Background Modes** → tick
**Remote notifications**. Required so a `content-available` push can wake the
app in the background (the backend sends `content-available: 1`).

### 2.4 Create the **APNs Auth Key (.p8)** and upload it to Firebase
This is what bridges FCM → Apple's push service. Skipping it is the #1 reason
"Android gets pushes, iPhone gets nothing."

1. Apple Developer portal → **Certificates, Identifiers & Profiles → Keys →
   +** → enable **Apple Push Notifications service (APNs)** → download the
   **`.p8`** (you can only download it once — keep it safe). Note the **Key
   ID** and your **Team ID**.
2. Firebase Console → project `saqqar-ai` → **Project settings → Cloud
   Messaging → Apple app configuration → APNs Authentication Key → Upload**.
   Provide the `.p8`, Key ID, and Team ID.

### 2.5 Confirm the App ID has Push enabled
Apple Developer portal → **Identifiers → `sa.com.digitalharbor.saqqar`** →
ensure **Push Notifications** is checked. (Adding the capability in Xcode with
automatic signing usually does this; verify it.)

### 2.6 Notes
- Firebase iOS SDK (firebase_messaging 15.x) requires **iOS 13+** — already
  the deployment target. The generated Podfile should keep
  `platform :ios, '15.0'` — Apple's own floor from Spring 2027 (ITMS-90068).
- **Real device only.** The iOS Simulator cannot receive remote push
  (Simulator push only works via a local `.apns` file drag, not the live
  pipeline). Test approval/run/artifact pushes on a physical iPhone.
- AppDelegate needs **no manual edits** for this — `firebase_messaging` does
  the APNs↔FCM token swizzling automatically once the capability is on.

---

## 3) ⛏️ Share Extension ("Share → Saqqar" on iOS)

On iOS an app only appears in the system share sheet if it ships a **Share
Extension** target. The Swift/plist/storyboard/entitlement files are already
in the repo under `ios/Share Extension/`, but the Xcode **target**, the
**App Group** capability on both targets, the **Podfile** block, and
**signing** can only be done on a Mac.

➡️ **Follow `docs/IOS_SHARE_EXTENSION_SETUP.md` in full** (§3 onward). It is the
detailed, self-contained guide for this one piece. Summary of what it makes you
do on the Mac:

- Create the **`Share Extension`** target in Xcode and point it at the repo's
  existing files.
- Add the **App Group `group.sa.com.digitalharbor.saqqar`** capability to
  **both** the Runner and the Share Extension targets, and register it in the
  Apple Developer portal.
- Add the `Share Extension` target block to the **Podfile** and run
  `pod install`.
- Match the extension's version/build to Runner.

The App Group registration in §3 also benefits nothing else, so it's safe to
do as part of this step only.

---

## 4) ⛏️ Signing, bundle id, and provisioning (Apple account required)

- The **bundle id `sa.com.digitalharbor.saqqar`** must exist under the team's
  Apple Developer account, with **Push Notifications** and **App Groups**
  capabilities enabled on the App ID.
- Set a **signing Team** on the **Runner** target (and the **Share Extension**
  target) in **Signing & Capabilities**. Automatic signing is fine.
- The Share Extension gets its **own** bundle id under the host namespace
  (Xcode suggests `sa.com.digitalharbor.saqqar.Share-Extension`).
- App Store Connect rejects **version/build mismatches** between Runner and the
  extension — keep both at `$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)`.

None of this is possible from Windows (no Xcode, no keychain, no provisioning).

---

## 5) ⛏️ CocoaPods (`pod install`)

The `ios/Podfile` and `ios/Pods/` are generated on a Mac (the repo doesn't
ship them — they're git-ignored). After `flutter pub get`, run:

```bash
cd ios
pod install        # pulls Firebase, permission_handler, receive_sharing_intent, etc.
cd ..
```

Do this **after** adding the Share Extension target (so its Podfile block, §3,
is included) and **after** the §6 Podfile edit.

---

## 6) ⛏️ Podfile hardening for `permission_handler` (recommended)

`permission_handler` compiles **every** iOS permission handler into the binary
by default (camera, location, contacts, calendar, etc.), even though Saqqar
only ever asks for the **microphone**. Apple's static analysis then expects a
usage string for each, and reviewers may ask why an unused permission is
present. Two ways to satisfy this — the repo already did the first; the second
is cleaner and is a Mac-side Podfile edit:

**Option A (already done):** usage strings for Camera + Location are in
Info.plist as stopgaps. Builds pass, but reviewers *might* ask.

**Option B (recommended):** strip the unused handlers at compile time. In the
generated `ios/Podfile`, in the `post_install do |installer|` block, add:

```ruby
installer.pods_project.targets.each do |target|
  flutter_additional_ios_build_settings(target)
  target.build_configurations.each do |config|
    config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
      '$(inherited)',
      'PERMISSION_MICROPHONE=1',
      # everything else OFF — keeps the binary clean of APIs we never use:
      'PERMISSION_CAMERA=0',
      'PERMISSION_PHOTOS=0',
      'PERMISSION_LOCATION=0',
      'PERMISSION_NOTIFICATIONS=1',   # set 1 only if you drive push prompts via permission_handler
      'PERMISSION_CONTACTS=0',
      'PERMISSION_EVENTS=0',
      'PERMISSION_REMINDERS=0',
      'PERMISSION_BLUETOOTH=0',
      'PERMISSION_SPEECH_RECOGNIZER=0',
      'PERMISSION_MEDIA_LIBRARY=0',
      'PERMISSION_SENSORS=0',
      'PERMISSION_APP_TRACKING_TRANSPARENCY=0',
      'PERMISSION_CRITICAL_ALERTS=0',
    ]
  end
end
```

If you take Option B you may also remove the now-unneeded
`NSCameraUsageDescription` / `NSLocationWhenInUseUsageDescription` from
Info.plist. Keep `NSMicrophoneUsageDescription`, `NSPhotoLibraryUsageDescription`,
and `NSFaceIDUsageDescription`.

> **Note on the speech key:** `ios/Runner/Info.plist` still contains
> `NSSpeechRecognitionUsageDescription`, but voice input was switched from the
> old on-device `speech_to_text` to server-side Whisper (`/api/v1/transcribe/`),
> so **on-device speech recognition is no longer used**. This key can be
> removed (optional cleanup) to avoid a reviewer asking about it.

---

## 7) Deep links — the custom scheme is free, Universal Links are not

> **Corrected 2026-08-12.** This section used to say the app does not use
> Universal Links and needs no Associated Domains. That stopped being true on
> 2026-07-22, when `applinks:saqqaar.com` was added to all three entitlements
> files. Left visible rather than silently rewritten, because anyone who read
> the old text would have skipped a capability the build now requires.

The **custom URL scheme** (`saqqar://…`) is registered in `CFBundleURLTypes`
and needs no entitlement and no Apple configuration — it works as soon as the
app is installed. Push notification payloads still use it.

**Universal Links do need Mac/portal work.** All three entitlements files
declare `com.apple.developer.associated-domains → applinks:saqqaar.com`, so:

- [ ] Enable **Associated Domains** on App ID `sa.com.digitalharbor.saqqarapp`
      in the Apple Developer portal, and regenerate the provisioning profiles.
      Without it the build **fails to sign** — this is not a silent
      degradation.
- [ ] Confirm the backend serves
      `https://saqqaar.com/.well-known/apple-app-site-association` over HTTPS
      with `Content-Type: application/json` and **no** redirect.

---

## 7b) ✅ Localized OS permission prompts — **done, nothing to do**

**Committed 2026-08-12. Pull and build; there is no Xcode step.**

`ios/Runner/en.lproj/InfoPlist.strings` and `ios/Runner/ar.lproj/InfoPlist.strings`
hold the four permission sentences — camera, microphone, photo library, Face ID.
iOS draws those in its own dialog *before* the user has seen a single Saqqar
screen, so nothing in `AppStrings` can reach them: without these files an Arabic
user is asked for their microphone in English.

Both files are already wired into `Runner.xcodeproj/project.pbxproj` as a
single `InfoPlist.strings` **variant group** in the Runner target's
**Copy Bundle Resources** phase, with `ar` added to `knownRegions`. That is the
same set of objects Xcode itself writes, so opening the project and adding them
again would only create duplicates.

It works at all because `Info.plist` declares `CFBundleLocalizations = [en, ar]`
— iOS does not look for `ar.lproj` in a bundle that claims not to speak Arabic.

**To verify on a device (worth doing once):** set the phone's language to
العربية, delete and reinstall, and tap the composer's mic button. The prompt
must read «يستخدم صقّار الميكروفون للإدخال الصوتي في المحادثة…». If it is in
English, the variant group did not survive a project merge — see below.

**Guarded by `test/platform_manifest_test.dart`**, which fails if a permission
is added to `Info.plist` without a matching line in both `.strings` files, **and**
if the four `pbxproj` objects or the `ar` region go missing. A merge conflict in
`project.pbxproj` resolved the wrong way is the realistic way this breaks, and
it now turns the suite red instead of shipping English prompts.

---

## 8) Optional: macOS target Firebase bundle id

`lib/firebase_options.dart` has the **macOS** Firebase entry pointing at the
placeholder bundle id `com.example.saqqarApp`. This only matters if you ever
ship the **macOS** build to the Mac App Store (not part of the iPhone work). If
so, re-run `flutterfire configure` for macOS with the real bundle id. **Ignore
for the iPhone release.**

---

## 9) Acceptance checklist (hand back when all are ticked)

**Push (§2)**
- [ ] `GoogleService-Info.plist` (iOS) downloaded and added to the **Runner**
      target (in Copy Bundle Resources), at `ios/Runner/GoogleService-Info.plist`.
- [ ] **Push Notifications** capability on Runner (adds `aps-environment`).
- [ ] **Background Modes → Remote notifications** enabled on Runner.
- [ ] **APNs `.p8` key** created in Apple portal and **uploaded to Firebase →
      Cloud Messaging** (with Key ID + Team ID).
- [ ] App ID `sa.com.digitalharbor.saqqar` has **Push Notifications** enabled.
- [ ] Real-device test: a push from the backend (or Firebase console "Send test
      message" to the device token) arrives and tapping it opens the chat.

**Share Extension (§3 / companion doc)**
- [ ] `Share Extension` target created and signed; repo files wired in.
- [ ] **App Group `group.sa.com.digitalharbor.saqqar`** on **both** targets and
      registered in the Apple portal.
- [ ] Podfile has the `Share Extension` block; `pod install` ran.
- [ ] Real-device test: Photos/Files/WhatsApp **Share → Saqqar** appears and
      foregrounds the app with the file staged.

**Signing / build (§4–§6)**
- [ ] Signing Team set on Runner + Share Extension; versions/build match.
- [ ] `flutter pub get` → `pod install` succeed; `flutter build ios` succeeds.
- [ ] (Recommended) `permission_handler` Podfile macros applied (§6).
- [ ] Info.plist still has: `NSMicrophoneUsageDescription`,
      `NSPhotoLibraryUsageDescription`, `NSFaceIDUsageDescription`, the
      `saqqar` scheme, and the `ShareMedia-<bundle id>` scheme.

**Sanity (already true, just confirm survived Xcode)**
- [ ] Face ID lock prompts on a real device (no extra capability needed).
- [ ] Mic permission prompt appears the first time voice input is used.

---

## 10) Build & run (Mac)

```bash
flutter clean
flutter pub get
cd ios && pod install && cd ..
# Sentry DSN is passed at build time; ask the mobile owner for the value:
flutter build ios --dart-define=SAQQAR_SENTRY_DSN=<dsn>
# or open ios/Runner.xcworkspace and run the Runner scheme on a real device.
```

Everything in this doc is independent of the Dart code — the Flutter side is
already built to use these capabilities the moment the native config above is
in place.
