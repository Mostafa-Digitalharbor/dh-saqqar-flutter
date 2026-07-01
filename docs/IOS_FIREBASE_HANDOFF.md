# iOS Firebase / Push — Mac handoff (for Claude on the Mac)

> **Who this is for:** the developer with the Mac + Xcode + Apple Developer
> account, and the Claude instance helping them. **Read this top to bottom —
> it is self-contained.** It tells you (1) exactly what has already been done
> from the Windows side so you don't redo it, (2) the one file you must
> download from Firebase and where to put it, and (3) every remaining
> Mac-only step, in order. The last section (§7) asks you to run a **full
> review of the project** and report anything missing or broken.
>
> Companion docs already in the repo: `docs/IOS_NATIVE_SETUP.md` (master
> Mac checklist) and `docs/IOS_SHARE_EXTENSION_SETUP.md` (share sheet). This
> file is the **push/Firebase focus** and supersedes the push section of the
> master doc where they differ (this one is newer).

---

## 0) Identifiers (use verbatim — do not invent new ones)

| Thing | Value |
|---|---|
| Host app bundle id | `sa.com.digitalharbor.saqqar` |
| iOS deployment target | `13.0` (already set in the Xcode project) |
| Firebase project id | `saqqar-ai` |
| Firebase iOS app id | `1:55105284059:ios:8518bc677c9023356ca9fe` |
| FCM sender id | `55105284059` |
| App Group id | `group.sa.com.digitalharbor.saqqar` |
| Deep-link scheme | `saqqar` (e.g. `saqqar://chats/<id>`) |

Plugin versions in `pubspec.yaml` (already committed): `firebase_core ^3.6.0`,
`firebase_messaging ^15.1.3`, `flutter_local_notifications ^18.0.1`.

---

## 1) ✅ Already done from Windows (DO NOT redo — just verify it survived)

The entire Dart side plus the **plain-text native config** is committed. When
you open Xcode and toggle capabilities, Xcode rewrites plist/entitlements/
pbxproj files — **after any capability change, re-confirm the items below still
exist** (Xcode sometimes drops them).

1. **`firebase_options.dart`** exists with the real iOS entry (bundle id +
   app id above). `Firebase.initializeApp()` is called at boot in
   `lib/main.dart`, and the FCM client wiring (token registration, foreground
   + background handlers, local-notification channels, tap→route) lives in
   `lib/features/push/`.
2. **Info.plist → `UIBackgroundModes` = [`remote-notification`]** — I added
   this from Windows. **This is the same thing the "Background Modes → Remote
   notifications" capability writes**, so you do NOT need to re-add that
   capability by hand; it's already declared. (Verify it's still there after
   Xcode rewrites.)
3. **`Runner.entitlements` → `aps-environment` = `development`** — I added
   this. It's what the "Push Notifications" capability adds. `development` is
   the correct committed value; Apple auto-switches to production APNs for App
   Store/TestFlight — **do not change it to `production`**. The file also
   already has the **App Group** `group.sa.com.digitalharbor.saqqar`.
   - ⚠️ **BUT** `Runner.entitlements` is **not yet wired into the target** —
     the pbxproj has no `CODE_SIGN_ENTITLEMENTS` pointing at it. See §3: adding
     the App Group / Push capability in **Signing & Capabilities** makes Xcode
     set `CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements` and activate
     both entitlements. Until that happens, neither push nor the App Group take
     effect. (Alternatively set that Build Setting by hand.)
4. **All five usage strings + both URL schemes** are in Info.plist
   (`NSMicrophoneUsageDescription`, `NSPhotoLibraryUsageDescription`,
   `NSFaceIDUsageDescription`, `NSCameraUsageDescription`,
   `NSLocationWhenInUseUsageDescription`; schemes `saqqar` +
   `ShareMedia-sa.com.digitalharbor.saqqar`).

---

## 2) ⛏️ Download `GoogleService-Info.plist` (the one file you MUST fetch)

**This file is git-ignored on purpose** (it carries API keys) — it is **not in
the repo** and will never arrive via `git pull`. You download it once and place
it on disk.

1. Firebase Console → project **`saqqar-ai`** → **Project settings** → *Your
   apps* → the **iOS app** with bundle id `sa.com.digitalharbor.saqqar`
   (app id `1:55105284059:ios:8518bc677c9023356ca9fe`).
   - If the iOS app doesn't exist yet: **Add app → iOS**, bundle id exactly
     `sa.com.digitalharbor.saqqar`.
2. Click **Download GoogleService-Info.plist**.
3. Put it at **`ios/Runner/GoogleService-Info.plist`** (same folder as
   `Info.plist`).
4. In Xcode, drag it into the **`Runner`** group → dialog: **✔ Copy items if
   needed**, **Target ✔ Runner**. Confirm it lands in **Runner target → Build
   Phases → Copy Bundle Resources**. If it's not in Copy Bundle Resources,
   `Firebase.initializeApp()` throws at launch.
5. Leave it git-ignored (recommended). If the team wants it in this **private**
   repo, that's a team call — but do not push it to any public mirror.

> Sanity check: the `BUNDLE_ID` inside the downloaded plist must read
> `sa.com.digitalharbor.saqqar`. A mismatched plist is the #1 cause of
> "Firebase initialized but no token".

---

## 3) ⛏️ Wire capabilities in Xcode (activates the entitlements from §1.3)

Open `ios/Runner.xcworkspace` (the **workspace**, not the project). Select the
**Runner** target → **Signing & Capabilities**:

1. Set a **Team** (Automatic signing is fine).
2. **+ Capability → Push Notifications.** Xcode sees `aps-environment` is
   already present and wires `CODE_SIGN_ENTITLEMENTS` to
   `Runner/Runner.entitlements`. It also enables Push on the App ID (automatic
   signing).
3. **+ Capability → App Groups.** Ensure `group.sa.com.digitalharbor.saqqar`
   is ticked (it's already in the entitlements file). Register the same group
   in the Apple Developer portal if prompted.
4. **Background Modes:** already declared via Info.plist (§1.2). If you add the
   capability in the UI too, make sure only **Remote notifications** is ticked
   and that you didn't drop the plist array.

> After this, re-open `Info.plist` and `Runner.entitlements` and confirm §1's
> keys all survived.

---

## 4) ⛏️ APNs Auth Key (.p8) → upload to Firebase (bridges FCM → Apple)

Skipping this = "Android gets pushes, iPhone gets nothing." Do it once.

1. **Apple Developer portal → Certificates, Identifiers & Profiles → Keys →
   +** → enable **Apple Push Notifications service (APNs)** → **Continue** →
   **Register** → **Download the `.p8`** (downloadable **once** — store it
   safely). Note the **Key ID** and your **Team ID**.
2. **Firebase Console → project `saqqar-ai` → Project settings → Cloud
   Messaging → Apple app configuration → APNs Authentication Key → Upload** →
   provide the `.p8`, **Key ID**, **Team ID**.
3. Confirm **Identifiers → `sa.com.digitalharbor.saqqar` → Push Notifications**
   is checked (step §3.2 usually does this; verify).

---

## 5) ⛏️ CocoaPods — Podfile + `pod install`

There is **no `Podfile` in the repo** (it's Mac-generated). After `flutter pub
get`, a Podfile appears under `ios/`. Firebase needs a static-framework
linkage, and we want to strip unused `permission_handler` handlers. Make the
`ios/Podfile` match this shape:

```ruby
platform :ios, '13.0'          # Firebase iOS SDK requires 13+
$FirebaseSDKVersion = '11.4.0' # optional pin; omit to let the plugin choose

# Firebase's static frameworks link cleanly with Flutter when declared static:
use_frameworks! :linkage => :static
use_modular_headers!

# ... (leave the default Flutter/target boilerplate the tool generated) ...

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
      # permission_handler ships every handler by default; keep only what
      # Saqqar actually uses (microphone + notifications) so Apple's static
      # check doesn't flag unused permission APIs.
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
        '$(inherited)',
        'PERMISSION_MICROPHONE=1',
        'PERMISSION_NOTIFICATIONS=1',
        'PERMISSION_CAMERA=0',
        'PERMISSION_PHOTOS=0',
        'PERMISSION_LOCATION=0',
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
end
```

Then:

```bash
flutter clean
flutter pub get
cd ios && pod install && cd ..
```

If you also add the **Share Extension** target (companion doc), add its Podfile
block **before** running `pod install`.

---

## 6) ⛏️ Build, run, and real-device push test

```bash
# Sentry DSN is injected at build time — ask the mobile owner for the value:
flutter build ios --dart-define=SAQQAR_SENTRY_DSN=<dsn>
# or: open ios/Runner.xcworkspace and run the Runner scheme on a REAL iPhone.
```

- **Real device only** — the iOS Simulator cannot receive live remote push.
- On first launch the app requests notification permission (the Dart side
  calls `requestPermission()` + registers the FCM token). Watch the Xcode
  console for a line like `FCM token = …`.
- Test delivery two ways: **Firebase Console → Cloud Messaging → Send test
  message** to that token, AND a real backend push (approval/run/artifact).
  Tapping the notification should open the right chat.
- **If a foreground notification doesn't appear** (background/tapped work but
  foreground banner doesn't): the usual iOS fix is to set the notification
  center delegate in `ios/Runner/AppDelegate.swift`:
  ```swift
  if #available(iOS 10.0, *) {
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
  }
  ```
  Only add this if foreground banners are missing — `firebase_messaging`
  handles the APNs↔FCM token swizzling automatically, so background/tap already
  work without any AppDelegate edit. Add it *after* `GeneratedPluginRegistrant`.

---

## 7) 🔍 Full project review (please run this and report back)

Before you build, do a **complete pass over the repo** and report anything
missing, conflicting, or wrong — not just push. Specifically check:

- **Analyzer + tests:** `flutter analyze` should be clean and `flutter test`
  green (34 tests as of this handoff). Report any new failures.
- **iOS config integrity:** after you toggle capabilities, verify Info.plist
  still has all five usage strings, both URL schemes, and
  `UIBackgroundModes=[remote-notification]`; and `Runner.entitlements` still
  has `aps-environment` + the App Group. Confirm `CODE_SIGN_ENTITLEMENTS` now
  points at `Runner/Runner.entitlements`.
- **Firebase wiring:** `GoogleService-Info.plist` is in Copy Bundle Resources;
  its `BUNDLE_ID` matches `sa.com.digitalharbor.saqqar`; `firebase_options.dart`
  iOS entry matches the app id above.
- **Version/build parity:** Runner and (if created) the Share Extension share
  `$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)` — App Store Connect
  rejects mismatches.
- **Deployment target consistency:** project, Podfile, and any extension all at
  **13.0+**.
- **Dead config:** `Info.plist` still carries `NSSpeechRecognitionUsageDescription`
  though voice now uses server-side Whisper (`/api/v1/transcribe/`), not
  on-device recognition — safe to remove to avoid a reviewer question (optional).
- **Push client code:** skim `lib/features/push/` and `lib/main.dart` for the
  token-registration + background-handler wiring and flag anything that looks
  iOS-incompatible.
- **Anything else** you notice while building: signing, provisioning, pod
  conflicts, Swift version, etc.

Please reply with: what you completed, what's still blocked (and why), and the
output of `flutter analyze` + `flutter test`.

---

## 8) Acceptance checklist (tick and hand back)

- [ ] `GoogleService-Info.plist` downloaded, at `ios/Runner/GoogleService-Info.plist`, in **Copy Bundle Resources** (Runner target).
- [ ] Push Notifications + App Groups capabilities added → `CODE_SIGN_ENTITLEMENTS` now points at `Runner/Runner.entitlements`.
- [ ] `UIBackgroundModes=[remote-notification]` present (pre-added — just confirm).
- [ ] APNs `.p8` created and uploaded to Firebase → Cloud Messaging (Key ID + Team ID).
- [ ] App ID `sa.com.digitalharbor.saqqar` has Push Notifications enabled.
- [ ] Signing Team set; `flutter pub get` → `pod install` → `flutter build ios` succeed.
- [ ] Real-device: Firebase test message **and** a backend push arrive; tap opens the chat.
- [ ] `flutter analyze` clean, `flutter test` green.
- [ ] Full review (§7) done and reported.
