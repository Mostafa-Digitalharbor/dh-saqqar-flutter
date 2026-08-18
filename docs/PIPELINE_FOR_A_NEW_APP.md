# Porting this pipeline to another Flutter app

Written after wiring it up for Saqqar end to end (2026-08-18). The workflow
files copy across in about ten minutes. Everything that actually cost time was
account setup and pre-existing inconsistencies in the repo — so this is
ordered by what will bite, not by what is quickest to type.

`docs/RELEASE.md` describes how the pipeline works. This describes how to move
it.

---

## 1. What you already have and do NOT redo

These are per **team/account**, not per app. Reusing them is the difference
between an afternoon and twenty minutes.

| Asset | Scope | What to do for app #2 |
|---|---|---|
| Apple Distribution certificate (`.p12`) | One per Apple team | Reuse. Same `IOS_DIST_CERT_P12_BASE64` + password. |
| App Store Connect API key (`.p8`) | One per Apple team | Reuse. Same key id / issuer id / p8. |
| Play service account JSON | One per Play developer account | Reuse — but **grant it access to the new app** in Play Console → Users and permissions → App permissions → Add app. |
| Apple Team ID | One per team | Same value (`P95FNYY2S2`). |

An Apple team is capped at **three** distribution certificates. Do not generate
a fourth for a second app — you will lock someone out.

### Per-app, must be new

| Asset | Where it comes from |
|---|---|
| Android upload keystore (`.jks`) | `keytool -genkey` — a fresh one per app |
| `google-services.json` | The app's own Firebase project |
| Bundle IDs / applicationId | The app's own |
| Sentry DSN | The app's own Sentry project |

---

## 2. Files to copy

```
.github/workflows/ci.yml
.github/workflows/release.yml
ios/Gemfile
ios/fastlane/Appfile
ios/fastlane/Fastfile
```

Plus the `.gitignore` block covering `ios/build/`, `ios/fastlane/report.xml`,
`build/dist_cert.p12`, `**/AuthKey_*.p8`.

---

## 3. What to change in them

### `.github/workflows/release.yml`

| Line | Value | New value |
|---|---|---|
| `FLUTTER_VERSION` | `'3.38.10'` | whatever the new app's **native code** requires — see §5.1 |
| `VERSION_CODE_OFFSET` | `200` | **above the highest `versionCode` already live on Play for that app** |
| `base64 -d > android/…jks` | `saqqar-release.jks` | the new keystore filename |
| `storeFile=` | `saqqar-release.jks` | same filename |
| `packageName:` | `sa.com.digitalharbor.saqqar` | the new `applicationId` |
| `SAQQAR_SENTRY_DSN`, `SAQQAR_GOOGLE_SERVER_CLIENT_ID`, `SAQQAR_WEB_SUBSCRIBE` | Saqqar's dart-defines | whatever `String.fromEnvironment` keys the new app actually reads — grep for `fromEnvironment` |

`VERSION_CODE_OFFSET` is the one that cannot be fixed later. Play refuses a
`versionCode` it has ever seen, permanently. Check the current highest in Play
Console before picking it, and leave headroom.

### `ios/fastlane/Appfile`

```ruby
app_identifier("<the Runner target's bundle id>")
team_id("<same team id>")
```

The bundle id is often **not** the Android `applicationId` — Saqqar ships
`sa.com.digitalharbor.saqqar` on Android and `sa.com.digitalharbor.saqqarapp`
on iOS. Read it out of `Runner.xcodeproj`, do not assume.

### `ios/fastlane/Fastfile`

* `output_name:` — cosmetic, rename.
* The `--dart-define` list — same keys as release.yml.
* `SAQQAR_WEB_SUBSCRIBE=false` is a Saqqar-specific store-policy decision
  (App Store 3.1.1). Drop it unless the new app has the same constraint.
* `workspace:` / `scheme:` stay `Runner.xcworkspace` / `Runner` for any
  standard Flutter app.

### `.github/workflows/ci.yml`

* `branches:` — match the new repo's branch names.
* artifact `name:` — cosmetic.

---

## 4. Secrets to create on the new repo

Twelve. Six are copy-paste from the existing repo (§1), six are new.

**Reused verbatim:**
`APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`,
`APP_STORE_CONNECT_P8`, `IOS_DIST_CERT_P12_BASE64`,
`IOS_DIST_CERT_PASSWORD`, `PLAY_SERVICE_ACCOUNT_JSON`

**New per app:**
`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`,
`ANDROID_KEY_PASSWORD`, `GOOGLE_SERVICES_JSON`, `SAQQAR_SENTRY_DSN` (rename to
the new app's define key)

> The App Store Connect key **must have the `Admin` role.** `App Manager` is
> enough to upload a build but NOT to cloud-sign, and the failure reads
> `exportArchive Cloud signing permission error / No profiles were found` —
> which looks like a provisioning problem, not a permissions one.

---

## 5. The traps, in the order they will hit you

Every one of these cost a full CI round trip on Saqqar.

### 5.1 The pinned Flutter version must match the native code

Check **before** the first run:

```bash
grep -rn "FlutterImplicitEngineDelegate\|SceneDelegate" ios/Runner/
grep -n "UIApplicationSceneManifest" ios/Runner/Info.plist
```

Any hit means the app is on the UIScene embedding and needs **Flutter ≥ 3.38**.
Pinning lower fails at Swift compilation with `Cannot find type
'FlutterImplicitEngineDelegate' in scope`, which says nothing about versions.

On a Windows machine this is invisible — `flutter build ios` cannot run at all,
so nothing catches it until CI compiles the iOS target for the first time.

### 5.2 `MinimumOSVersion` must be present AND at least 15.0

```xml
<key>MinimumOSVersion</key>
<string>15.0</string>
```

in `ios/Flutter/AppFrameworkInfo.plist`, matching `IPHONEOS_DEPLOYMENT_TARGET`
in every build configuration and `platform :ios` in the Podfile.

Two distinct failures, and **both land after a successful upload** — the
archive builds, signs and ships, so CI is green for either:

* **Missing** → hard rejection at validation:
  `MinimumOSVersion in 'Runner.app/Frameworks/App.framework' is ''`.
* **Below 15.0** → `ITMS-90068: MinimumOSVersion too low`, emailed once the
  build reaches TestFlight and shown as a yellow warning triangle beside it.
  A warning today; **from Spring 2027 App Store Connect refuses the upload.**

Raising the floor to 15.0 costs no devices: iOS 15 runs on every iPhone that
could run iOS 13 (6s and later) — it is the last release supporting the 6s.

Pods carry their own `MinimumOSVersion` and Apple validates the lowest one in
the bundle, so force the floor in the Podfile's `post_install` too —
`flutter_additional_ios_build_settings` only raises a pod to *Flutter's*
minimum, not yours. Raise only; never lower a pod that demands something newer.

### 5.3 Xcode version

`Runner.xcodeproj` written by Xcode 16+ contains
`PBXFileSystemSynchronizedRootGroup`. Xcode 15 cannot parse it and does not
fail gracefully — `xcodebuild -list` aborts with a DVTAssertions failure and
signal 6. The `Select Xcode` step in release.yml picks the newest by version
sort; keep it, and keep the runner on `macos-15` or later.

Do not parse `xcodebuild -version` through `head` — under Xcode 26 it aborts on
EPIPE (`Broken pipe`, exit 134).

### 5.4 CocoaPods must live in the same Ruby as fastlane

`ruby/setup-ruby` puts a different Ruby on PATH than the one the macOS image
installed CocoaPods against. `flutter build ios` shells out to a bare `pod
install` and only warns — `CocoaPods is installed but broken` — then fails.
Declaring `gem "cocoapods"` in `ios/Gemfile` fixes it.

### 5.5 Gradle memory on a hosted runner

A private repo's `ubuntu-latest` is **2 vCPU / 7 GB**. If the project's
`android/gradle.properties` asks for `-Xmx8G` (fine on a workstation), the JVM
is OOM-killed and Gradle exits **143** with GitHub reporting
`The operation was canceled` — which reads like somebody pressed cancel. The
`Cap Gradle memory` step overrides it in `GRADLE_USER_HOME` so local builds
keep their larger heap.

### 5.6 Drop Jetifier unless something actually needs it

```bash
find ~/.gradle/caches/modules-2/files-2.1 -maxdepth 1 \
     \( -iname "com.android.support*" -o -iname "android.arch*" \) | wc -l
```

Zero means `android.enableJetifier=true` is rewriting hundreds of archives to
change nothing — and holding each in heap. On a 3 GB cap the **debug** build
dies on it (`JetifyTransform … Java heap space`) while release passes, because
debug pulls the x86/x86_64 engine jars too.

### 5.7 Disk

The Android build needs more than the ~14 GB the image leaves free once Gradle
unpacks the NDK and CMake. Running out surfaces as
`Could not add entry '…/transforms/…' to cache file-access.bin`, which reads
like cache corruption. Keep the `Free disk space` step.

### 5.8 `google-services.json` is gitignored but required

The `com.google.gms.google-services` plugin hard-fails without it, on **every**
Android build including debug. Both Android jobs restore it from the secret.

### 5.9 An empty `--dart-define` is not the same as omitting it

`String.fromEnvironment` uses its compiled-in `defaultValue` only when the key
is **absent**. `--dart-define=K=` passes an empty string, and the empty string
wins. Piping an unset secret straight through therefore *erases* a working
compiled-in default. Append the flag only when the secret is non-empty.

### 5.10 Google Sign-In needs the debug SHA-1 too

Only the release signing certificate's SHA-1 is registered, so
`flutter run` builds fail with `ApiException: 10` (`DEVELOPER_ERROR`). Add a
second Android OAuth client for the debug keystore's fingerprint:

```bash
keytool -list -v -keystore ~/.android/debug.keystore \
        -alias androiddebugkey -storepass android | grep SHA1
```

---

## 6. Order of operations

1. Copy the five files; make the §3 edits.
2. Run §5.1 and §5.2 checks locally — both are grep-able and both cost a full
   CI cycle if missed.
3. Create the Android keystore, add the six new secrets, copy the six shared
   ones.
4. Grant the Play service account access to the new app.
5. Enable **Google Play Android Developer API** on the service account's Cloud
   project (once per Cloud project, not per app).
6. Push to a branch — `ci.yml` runs analyze + tests + a debug APK and uploads
   nothing. Iterate here; it is free.
7. Only when that is green, `git tag vX.Y.Z`.

Steps 1–6 touch no store. The tag is the first thing that does.
