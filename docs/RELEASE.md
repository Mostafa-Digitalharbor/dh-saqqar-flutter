# Release pipeline

How a commit becomes an update on a user's phone, and what has to be set up
once before any of it works.

`PUBLISHING_GUIDE.md` covers the manual store-console steps (listings,
screenshots, data-safety forms). This file covers the automated half.

---

## 1. The three ways an app updates

They get conflated constantly, and they have wildly different latencies.

| Mechanism | What changes | Reaches the user in | Needs a store review |
|---|---|---|---|
| Store auto-update | The whole binary | **1–7 days** | Yes |
| In-app update prompt | The whole binary, but the user is *told* | Minutes–hours | Yes (same build) |
| Server-driven content | Nothing in the binary | Instantly | No |
| Shorebird code push | Dart code + assets only | Next app restart | No |

The store is the slow part, and it is slow **after** review — Play checks for
updates roughly daily and rolls out over days, and a user who turned
auto-update off never gets one at all. That gap is what §4 exists to close.

Saqqar already leans on the "server-driven" row more than it looks: plan copy,
taglines and badges come from `/api/v1/plans/`, and the tools sheet is gated by
`saqqar_features` off `/api/v1/usage/`. Anything that can move to the wire
should, because it ships in zero days.

---

## 2. Shipping a build

```bash
git tag v1.2.5
git push origin v1.2.5
```

That is the whole trigger. `.github/workflows/release.yml` then:

1. **verify** — `flutter analyze` + `flutter test` (1546 tests). Nothing is
   built if this fails.
2. **version** — derives `build_name` from the tag (`v1.2.5` → `1.2.5`) and
   `build_number` from `200 + github.run_number`. A tag that is not plain
   `vMAJOR.MINOR.PATCH` fails the job rather than shipping a malformed
   `CFBundleShortVersionString`.
3. **android** — builds a signed AAB and uploads it to the Play **internal**
   track.
4. **ios** — builds a signed IPA and uploads it to **TestFlight**, internal
   testers only.

Promotion to production is **deliberately manual**, in the Play Console and
App Store Connect. Two reasons, both current:

* Play rejected v15 for "Broken Functionality"; Apple has build 107 on a
  2.1(b) hold. Automating a production push right now sends unreviewed builds
  to the same reviewers who already rejected one.
* Production should go out as a **staged rollout** (start at 10 % on Play,
  phased release on Apple) with Sentry open. That is a judgement call with a
  human watching a dashboard, not a CI step.

`workflow_dispatch` lets you re-run a build without cutting a new tag, and
pick a different track / platform.

### The build number is not in pubspec

`pubspec.yaml` still says `1.2.4+115`, and that is what a local
`flutter build` uses. CI overrides both with `--build-name` / `--build-number`
so nobody can ship a duplicate `versionCode` by forgetting to bump a file.

`VERSION_CODE_OFFSET: 200` in the workflow exists because `github.run_number`
restarts at 1 if the workflow file is renamed or deleted. **If you ever rename
`release.yml`, raise the offset above the highest build code already live and
never lower it.** Play refuses a `versionCode` it has seen before, permanently.

---

## 3. One-time setup

Nothing below is in the repo. All of it goes in **Settings → Secrets and
variables → Actions**.

### Android

| Secret | Where it comes from |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 android/saqqar-release.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | the `storePassword` from `android/key.properties` |
| `ANDROID_KEY_PASSWORD` | the `keyPassword` |
| `ANDROID_KEY_ALIAS` | the `keyAlias` (`saqqar`) |
| `GOOGLE_SERVICES_JSON` | full contents of `android/app/google-services.json` |
| `PLAY_SERVICE_ACCOUNT_JSON` | see below |

The Play service account:

1. Google Cloud Console → the project behind Play → **Service Accounts** →
   create one → **Keys → Add key → JSON**.
2. Play Console → **Users and permissions** → invite that service account's
   email → grant **Release** on the Saqqar app.
3. Paste the whole JSON file as the secret value.

> Losing `saqqar-release.jks` or its passwords means you can **never** update
> the existing Play listing again. It is not recoverable. Keep it in the team
> password manager, not only on one laptop.

### iOS

| Secret | Where it comes from |
|---|---|
| `APP_STORE_CONNECT_KEY_ID` | App Store Connect → Users and Access → Integrations → App Store Connect API |
| `APP_STORE_CONNECT_ISSUER_ID` | same page, above the key list |
| `APP_STORE_CONNECT_P8` | contents of the downloaded `AuthKey_XXXX.p8` (downloadable **once**) |
| `IOS_DIST_CERT_P12_BASE64` | the Apple Distribution certificate + private key as a base64'd `.p12` — see below |
| `IOS_DIST_CERT_PASSWORD` | the password you set on that export |

The API key needs the **App Manager** role to upload builds. Note it is created
on **appstoreconnect.apple.com** (Users and Access → Integrations), *not* on
developer.apple.com — the APNs auth key Firebase uses is a different key of the
same `AuthKey_XXXX.p8` shape, created in the other portal, and it cannot upload
anything.

### Making the `.p12` without a Mac

No Mac is needed anywhere in this pipeline. The build runs on a hosted macOS
runner; the certificate is produced with OpenSSL on any platform. Keychain
Access is the usual route and it is not the only one — an earlier revision of
this file said a Mac was required, which was wrong.

```bash
openssl genrsa -out ios_dist.key 2048
openssl req -new -key ios_dist.key -out ios_dist.csr \
  -subj "/emailAddress=you@example.com/CN=Your Name/C=SA"
# upload ios_dist.csr at developer.apple.com → Certificates → + → Apple Distribution
# download distribution.cer, then:
openssl x509 -in distribution.cer -inform DER -out ios_dist.pem -outform PEM
openssl pkcs12 -export -legacy -inkey ios_dist.key -in ios_dist.pem \
  -out ios_dist.p12 -name "Apple Distribution"
base64 -w0 ios_dist.p12          # → IOS_DIST_CERT_P12_BASE64
```

Two traps. On Git Bash, prefix the `req` line with `MSYS_NO_PATHCONV=1` or the
`-subj` argument is mangled into a Windows path. And `-legacy` is required for
macOS's `security import` to accept an OpenSSL 3 bundle — it works in Git Bash
but fails in PowerShell, where the legacy provider DLL is not on the MSYS path.

Verify before uploading the secret — a `.p12` without the private key signs
nothing, and the CI failure for that is not obvious:

```bash
openssl pkcs12 -in ios_dist.p12 -legacy -nodes -nocerts | grep -c "PRIVATE KEY"
```

Keep `ios_dist.key` in the password manager. Losing it makes the certificate
worthless and burns one of the team's three distribution-certificate slots.

Saqqar has four iOS targets — Runner, Share Extension, Watch App and the Watch
Complication — all on `CODE_SIGN_STYLE = Automatic`. `ios/fastlane/Fastfile`
keeps them that way and lets Xcode fetch all four provisioning profiles itself
via `-allowProvisioningUpdates`, authenticated with the same API key. That is
why there is no `fastlane match` repo to maintain: the only signing state
carried is the one distribution certificate, because
`-allowProvisioningUpdates` can mint a certificate but cannot export its
private key, so letting it do so would burn the team's three-certificate limit
one CI run at a time.

### Shared

| Secret | Notes |
|---|---|
| `SAQQAR_SENTRY_DSN` | still missing — a release without it reports no crashes |
| `SAQQAR_GOOGLE_SERVER_CLIENT_ID` | Google sign-in is inert without it |

`SAQQAR_WEB_SUBSCRIBE` is a repository **variable**, not a secret; iOS forces
it to `false` in the Fastfile regardless, because the store binary must name no
prices while 2.1(b) is open.

---

## 4. The in-app update gate

`AppUpdateCubit` merges **two independent sources**, because they know
different things and neither is required:

| Source | Knows | Platform |
|---|---|---|
| `GET /api/v1/app/version/` | the supported **floor** — which builds the API still serves | both |
| Play In-App Updates | what is genuinely **installable** on this device today, and can install it without leaving the app | Android |

With only the backend you get both gates plus a store link. With only Play you
get the nudge plus an in-place install. With neither — the app behaves exactly
as it did before this feature existed.

**The Android half works today.** `/api/v1/app/version/` is still a 404, but
Play answers on its own, so an Android user already gets the nudge and a
one-tap background install. The backend endpoint adds the blocking floor and
covers iOS.

### The backend contract

Called on boot and on resume (throttled to once per 6 h; it stops asking
entirely once it is blocking). Expected shape:

```json
{
  "ok": true,
  "min_supported_build": 110,
  "latest_build": 118,
  "latest_version": "1.2.5",
  "store_url": "https://play.google.com/store/apps/details?id=sa.com.digitalharbor.saqqar"
}
```

* `current < min_supported_build` → full-screen wall, no dismiss, one button
  to the store.
* `current < latest_build` → dismissible banner under the header. The
  dismissal is remembered **per build number**, so "later" on 1.2.5 does not
  mute 1.2.6.
* Anything else, including a 404, an unreadable body, or no body at all →
  nothing happens. The app behaves exactly as it does today.

**This endpoint can take the entire installed base offline in one edit**, so
the client refuses to enforce three classes of nonsense (all covered in
`test/app_update_gate_test.dart`, and each guard verified to fail when
removed):

* `min_supported_build > latest_build` — demands a build that exists on no
  store, so no user could satisfy it. Never blocks.
* An empty `store_url` — the wall's only affordance would not work. Never
  blocks.
* A `buildNumber` the platform reports as non-numeric (iOS `CFBundleVersion`
  is free-form; `PackageInfo` returns `""` when its channel call fails).
  Parsing that as `0` would put every user on that platform below every floor.
  Never blocks.

`min_supported_build` is a weapon, not a convenience. Raise it only when an
old build is genuinely dangerous — a removed endpoint, a broken token format.
Use `latest_build` for everything else.

Play is never allowed to *block*. It only ever reports "something newer
exists" and has no concept of a supported floor, so promoting its answer to a
wall would lock users out for an ordinary release.

### What "Update now" actually does

One shared action (`view/update_action.dart`), three steps, in order:

1. **Install in place** — Play's own updater. `immediate` (Google's blocking
   full-screen UI) when the backend has declared the build unsupported,
   `flexible` (background download, then restart) otherwise. Severity picks
   the flow; it is not a preference.
2. **Open the store listing** — everything else, including all of iOS.
3. **Say so** — a toast if even the listing will not open. A tap that reports
   nothing is indistinguishable from a frozen app, and on the blocking wall
   that is the only button there is.

### Testing it on a device

`InAppUpdate.checkForUpdate()` throws on any install Play does not recognise
as its own — `flutter run`, a sideloaded APK, an emulator image. That is
normal, not a bug: `PlayUpdateService` swallows it and the flow falls back to
the store link. To exercise the real thing you need a build **installed from
Play** (internal track is enough) whose `versionCode` is lower than the one
currently published on that track.

### Store-policy note

`in_app_update` is a native plugin, and the last Play rejection was "Broken
Functionality". Its whole surface fails safe — every call is wrapped, and a
throw degrades to today's behaviour — but it is still native code added while
a resubmit is open. **Smoke-test the Android build on a real device before
promoting past the internal track.**

---

## 5. Shorebird (not wired, deliberate)

Shorebird is the only real code-push for Flutter. It patches the Dart AOT
snapshot, so a fix reaches users on their next app restart with no store
round-trip.

```bash
shorebird init
shorebird release android    # instead of flutter build appbundle
shorebird patch android      # every fix after that — seconds, no review
```

In CI it is `shorebirdtech/setup-shorebird` plus a `SHOREBIRD_TOKEN` secret.

**What it cannot patch**, which matters a lot for this app specifically:

* Any native code, including the native half of a plugin. Saqqar depends on
  `firebase_messaging`, `local_auth`, `record`, `pdfx`, `image_picker`,
  `receive_sharing_intent` and `share_plus` — a change touching any of their
  native sides needs a full release.
* Adding or removing a dependency, changing the Flutter engine version,
  bumping the app version, or changing permissions / icon / splash.

So the shape is: `git tag` for anything structural, `shorebird patch` for Dart
fixes. It is a strong fit for the "we shipped a crash on Tuesday" case and no
help at all for the two store holds currently open — which is why it is last
on the list, not first.

Both stores permit it (Apple's 3.3.2 allows downloaded interpreted code that
does not change the app's primary purpose), but the rule is bug fixes and
tweaks, not shipping a feature around review.

---

## 6. Known gap: the CI formatting gate

`.github/workflows/ci.yml` used to run
`dart format --set-exit-if-changed lib test`. The repo is not format-clean —
269 of 373 Dart files are rewritten by it — so that step failed on every
commit, which failed `analyze-and-test`, which `build-android` depends on via
`needs:`. The pipeline had been closed.

The gate was removed rather than the tree reformatted: a 269-file reformat
turns every future one-line fix into a several-hundred-file diff and destroys
`git blame`. `flutter analyze` is the quality bar.
