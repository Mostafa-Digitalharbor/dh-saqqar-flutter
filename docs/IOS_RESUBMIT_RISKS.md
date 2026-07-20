# iOS resubmission — additional rejection risks found (app-side)

Audit done 2026-07-13 while the backend Apple-Sign-In fix is in progress. These are
risks **beyond** the 3 items Apple already cited, found by reviewing the code. Each
must be applied/tested on a **Mac** (they touch native iOS build config).

Legend: 🔴 high risk · 🟠 medium risk · ✅ already fine.

---

## 🔴 1. Pricing screen shows prices + upgrade CTA (Guideline 3.1.1 — IAP)

`lib/features/billing/view/pricing_screen.dart` renders paid tiers with a **monthly
price** and an **"Contact us to upgrade"** CTA. It's reachable on iOS from 3 places
(`account_screen`, `current_plan_card`, `plan_usage_card`).

Apple routinely rejects apps that display prices for digital features and route the
upgrade outside In-App Purchase (even a "Contact us" is treated as steering). It was
not cited this round, but it's a live risk for the next review.

**Options (product decision):**
- **A. Hide on iOS (recommended, fastest):** on iOS, hide tier prices + the upgrade
  CTA; show only the current plan + usage (informational). Pure Dart change, no build
  risk. Android keeps the full screen.
- **B. Implement StoreKit IAP:** large effort; only if selling subscriptions in-app.
- **C. Argue multiplatform/enterprise exemption (3.1.3):** possible for a B2B Odoo
  copilot, but riskier than A for a resubmission.

> This is the only additional risk fixable purely in Flutter — waiting on your choice.

---

## ✅ 2. Permissions declared but never used — **APPLIED 2026-07-20**

> Everything in this section is now done in the repo. Kept for the reasoning.
>
> - `ios/Podfile` `post_install` now sets the `PERMISSION_*` macros, with
>   `PERMISSION_MICROPHONE=1` and everything else `0`.
> - `NSSpeechRecognitionUsageDescription` and
>   `NSLocationWhenInUseUsageDescription` removed from `ios/Runner/Info.plist`.
>   Verified first that **no** pod in the build references `CoreLocation`,
>   `CLLocationManager`, `SFSpeechRecognizer` or `import Speech`.
> - `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription` **kept** —
>   `image_picker` / `file_picker` drive those through their own APIs, not
>   through `permission_handler`, so the macros being `0` does not remove the
>   need for the strings.
> - `NSMicrophoneUsageDescription` was rewritten: it claimed "Audio is
>   processed on-device and never uploaded", but `TranscribeApi` POSTs the
>   recording to `/api/v1/transcribe/`, which runs OpenAI Whisper server-side.
>   A purpose string that misstates where the data goes is a privacy problem
>   independent of review.
>
> The macros were not optional cleanup: with all of them defaulting to `0`,
> `AudioVideoPermissionStrategy.m` compiled to an empty `@implementation`
> while `PermissionManager.m` still returned that class for
> `PermissionGroupMicrophone` — so the chat mic button hit an
> unrecognized selector and crashed the app on iOS.

### Original analysis

`permission_handler` compiles **every** permission handler by default, which forces
matching usage strings in `Info.plist`. The app actually uses only:

- **Microphone** — `record` (voice input) ✅ keep
- **Face ID** — `local_auth` (app lock) ✅ keep

- **Camera** — `image_picker` (the attach sheet's "Camera" row) ✅ keep

These are **not** used by any Dart code (documents go through `file_picker` /
`receive_sharing_intent`, transcription is server-side Whisper — no on-device
speech, no location):

- `NSSpeechRecognitionUsageDescription` — **remove** (no speech recognition in app)
- `NSLocationWhenInUseUsageDescription` — **remove** (no location anywhere)
- `NSPhotoLibraryUsageDescription` — verify: modern `file_picker` image pick uses
  PHPicker (no permission needed). Remove if the device test confirms no prompt.

> `NSCameraUsageDescription` was on this list until the attach sheet shipped
> (Photos / Camera / Files). `_pickFromCamera` in `chat_screen.dart` now calls
> `ImagePicker().pickImage(source: ImageSource.camera)`, so the key is load-bearing
> — deleting it crashes the capture on first tap.

### Fix (do together, in this order, on Mac)

**a) `ios/Podfile`** — inside the existing `post_install … config.build_configurations.each do |config|` loop, compile only the handlers used. Setting the rest to `0` stops the binary from referencing those permission APIs:

```ruby
# permission_handler: compile ONLY the handlers the app uses. Disabling the
# rest removes references to unused permission APIs (location, speech, …),
# which is what forced the unused Info.plist strings below.
defs = config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] || ['$(inherited)']
defs = defs.split(' ') if defs.is_a?(String)
defs |= [
  'PERMISSION_MICROPHONE=1',
  'PERMISSION_CAMERA=0',
  'PERMISSION_PHOTOS=0',
  'PERMISSION_LOCATION=0',
  'PERMISSION_SPEECH_RECOGNIZER=0',
  'PERMISSION_NOTIFICATIONS=0',
  'PERMISSION_CONTACTS=0',
  'PERMISSION_EVENTS=0',
  'PERMISSION_EVENTS_FULL_ACCESS=0',
  'PERMISSION_REMINDERS=0',
  'PERMISSION_MEDIA_LIBRARY=0',
  'PERMISSION_SENSORS=0',
  'PERMISSION_BLUETOOTH=0',
  'PERMISSION_APP_TRACKING_TRANSPARENCY=0',
  'PERMISSION_CRITICAL_ALERTS=0',
  'PERMISSION_ASSISTANT=0',
]
config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] = defs
```
> If a device test shows file attachments need the photo/camera prompt, flip
> `PERMISSION_PHOTOS`/`PERMISSION_CAMERA` back to `1` and keep those two strings.

**b) `ios/Runner/Info.plist`** — remove the keys for the disabled permissions
(`NSSpeechRecognitionUsageDescription`, `NSLocationWhenInUseUsageDescription`, and —
after the device test — `NSCameraUsageDescription` / `NSPhotoLibraryUsageDescription`).

**c)** `flutter clean && cd ios && pod install && cd ..`, rebuild, and **test on a real
device**: voice input still prompts for mic; attachments still work. Only remove a
string once you've confirmed its prompt no longer appears.

> ⚠️ Never remove a usage string while its `PERMISSION_*` macro is still `1` — the app
> would reference the API with no purpose string and crash / get flagged. String
> removal and macro disable are a matched pair.

---

## 🟠 3. Missing Privacy Manifest (`PrivacyInfo.xcprivacy`)

Required by Apple since May 2024 for apps using "required-reason" APIs. This app uses
`shared_preferences` (NSUserDefaults) + file caches, so it qualifies. Missing it
triggers the **ITMS-91053** email and can block review.

**Done for you — no Xcode step needed:**
- File created at `ios/Runner/PrivacyInfo.xcprivacy`.
- Already **registered in `Runner.xcodeproj/project.pbxproj`** (file reference +
  Runner group + Copy Bundle Resources), modelled on the existing
  `GoogleService-Info.plist` wiring. Once both files are pulled from the repo, it
  builds into the bundle directly — nothing to add in Xcode.

Only revisit if a plugin needs a different required-reason code (adjust the reasons
array in the `.xcprivacy`).

---

## ✅ Confirmed OK (not risks)

- **Account deletion (5.1.1(v))** — present and real: `delete_account_helper.dart` →
  `AuthCubit.deleteAccount()` irreversibly deletes server-side + clears local data.
- **Sign in with Apple button (4.8)** — shown on iOS; backend `aud` allowlist fix is
  the separate pending item (`docs/BACKEND_TODO_APPSTORE_RESUBMIT.md`).
- **Export compliance** — `ITSAppUsesNonExemptEncryption = false` declared.
- **Microphone permission flow (5.1.1(iv))** — fixed in Dart: native prompt first,
  optional Settings shortcut only after a permanent denial.
