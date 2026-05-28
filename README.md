# Saqqar Mobile — Odoo Operations Copilot

[![Flutter](https://img.shields.io/badge/Flutter-3.35-02569B?logo=flutter)](https://flutter.dev) [![Dart](https://img.shields.io/badge/Dart-3.9-0175C2?logo=dart)](https://dart.dev) [![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS-lightgrey)](#) [![Status](https://img.shields.io/badge/status-production-success)](#status) [![Version](https://img.shields.io/badge/version-1.0.21+22-blue)](#)

The native mobile companion to [saqqaar.com](https://saqqaar.com) — an AI agent for operating Odoo ERP systems. Users sign in, open a conversation, type or speak a request in natural language, and Saqqar uses live tools (Odoo XML-RPC, PostgreSQL, server shell, GitHub) to diagnose, report, and act — with every risky change gated behind explicit approval.

This Flutter client mirrors the web product's behavior on a phone, plus mobile-native superpowers: voice dictation via Whisper, share-to-app from WhatsApp / Photos / Files, encrypted on-device credential vault, and push-style polling for approvals.

> **Product:** Saqqar  ·  **Domain:** saqqaar.com (double-a)  ·  **Owner:** Digital Harbor
> **App ID:** `sa.com.digitalharbor.saqqar`  ·  **Backend:** `/api/v1/` (see [SAQQAR_MOBILE_API.md](../saqqar/SAQQAR_MOBILE_API.md))

---

## Table of contents

- [Status](#status)
- [Features](#features)
- [Tech stack](#tech-stack)
- [Project structure](#project-structure)
- [Design system](#design-system)
- [Internationalization](#internationalization)
- [Getting started](#getting-started)
- [Build & release](#build--release)
- [Backend integration](#backend-integration)
- [Observability](#observability)
- [Contributing](#contributing)

---

## Status

**Production — shipping on Google Play.** Internal Testing closed; staged rollout in progress.

The mobile app is feature-complete against the v1 spec and integrated with the live production backend at `saqqaar.com`. Every screen renders from real API data; demo data is reserved for the storybook and tests.

**What ships in v1**

- ✅ Real token-based auth against `/api/v1/auth/`
- ✅ Conversations list — search, archive, swipe-to-archive, long-press menu, pull-to-refresh
- ✅ Chat — message stream, typing indicator, tool activity, approvals inline, scroll-to-bottom, scroll restore on resume
- ✅ Attachments — multi-file picker, tap-to-preview (image fullscreen / file via system viewer), upload progress, batch confirmation toast
- ✅ Voice input — server-side Whisper via `/api/v1/transcribe/` (Arabic + English + code-switch auto-detect)
- ✅ Share intent — receive `ACTION_SEND` / `ACTION_SEND_MULTIPLE` from WhatsApp, Photos, Files; outbound share of any agent reply via `share_plus`
- ✅ Credentials vault — schema-driven editor with the new xmlrpc `auth_type` switcher (API Key / Password), Test Connection button, projects + environments
- ✅ Approvals — inline approval cards in chat, decision API wired, per-conversation pulse-dot on the list
- ✅ Artifacts — download + open with the OS's matching viewer (PDF, Excel, Word, images)
- ✅ Per-conversation toggles — Deep Think + Auto Approve with animated active-mode badges next to Send
- ✅ Dark + Light themes, English + Arabic with full RTL mirroring
- ✅ Sentry crash reporting with environmental-noise filtering
- ✅ Stop button: instant UI flip + restores last message into the composer for re-edit

**Phase 1 deferred**

- ⏳ Live streaming assistant text (still uses 1.5s/15s polling for now)
- ⏳ Push notifications via FCM (today: polling cadence drives approvals + chat updates)
- ⏳ iOS distribution (ready, awaiting App Store Connect rollout)
- ⏳ Live API streaming (SSE / WebSocket) — backend decision pending

---

## Features

### Chat & messaging
- Multi-file attachments with compact 72×72 thumbnails in the composer; tap to preview (fullscreen pinch-to-zoom for images, OS-native viewer for everything else)
- Voice dictation — hold mic → record (red dot + waveform + mm:ss + 2-min hard cap) → release → server transcribes via Whisper → text appears in composer (append, never replace)
- Long-press an agent reply → Copy or Share via the system share sheet
- Pulsing badges next to Send when Deep Think or Auto Approve is on
- Instant Stop that flips the UI immediately and restores your last message into the composer

### Conversations
- Search in titles + previews
- Long-press a row → bottom sheet with Pin / Rename / Share / Archive / Delete
- Swipe horizontally → Archive (active rows) or Unarchive (archived rows), with coloured drag affordance
- Archived bucket is a collapsible card under the search bar — not a separate tab
- Date grouping (Today / Yesterday / Previous 7 days / Older)

### Vault (credentials + projects)
- Schema-driven form (never hard-codes fields) — renders against `GET /api/v1/credentials/schemas/`
- xmlrpc kind supports API Key OR Password via a dropdown; secret field's label, placeholder and help text flip dynamically from the schema
- Test Connection button hits `POST /api/v1/credentials/test/` and shows green/red badge with the server's reason on failure
- Projects + environments with per-environment credential tabs
- Per-conversation environment binding (default + override)

### Share intent (Android)
- Receive `ACTION_SEND` and `ACTION_SEND_MULTIPLE` from WhatsApp / Photos / Files / etc.
- Picker overlay covers the entire screen the instant a share lands — user never sees the previously-open chat behind it
- Pick destination (new chat or any existing) → file appears in that chat's composer immediately (no rebuild flash)
- Cancel returns to the conversations list

### Account
- Profile + counts (conversations, credentials, approvals, artifacts)
- Theme: Light / Dark / System
- Language: English / Arabic
- Sign out

---

## Tech stack

| Layer            | Choice                                                                |
|------------------|-----------------------------------------------------------------------|
| Framework        | Flutter 3.35 / Dart 3.9                                               |
| State management | [flutter_bloc](https://pub.dev/packages/flutter_bloc) (Cubit + MVVM)  |
| Routing          | [go_router](https://pub.dev/packages/go_router) 14 (shell + nested)   |
| Networking       | [Dio](https://pub.dev/packages/dio) with auth + logging interceptors  |
| Secure storage   | `flutter_secure_storage` (Keychain / Keystore)                        |
| Preferences      | `shared_preferences`                                                  |
| Iconography      | [Lucide](https://lucide.dev) via `lucide_icons_flutter`               |
| Typography       | Platform default (Roboto / Noto Sans Arabic / SF / SF Arabic)         |
| Markdown         | `flutter_markdown`                                                    |
| File picker      | `file_picker` (attachments)                                           |
| Open files       | `path_provider` + `open_filex` (artifact + attachment download/open)  |
| Voice recording  | `record` 5.x (m4a / AAC / 16 kHz mono → server-side Whisper)          |
| Permissions      | `permission_handler` (mic, storage)                                   |
| Share — inbound  | `receive_sharing_intent` (`ACTION_SEND` / `ACTION_SEND_MULTIPLE`)     |
| Share — outbound | `share_plus` (long-press → system share sheet)                        |
| Crash reporting  | `sentry_flutter` + custom noise filter                                |
| Splash           | `flutter_native_splash`                                               |
| Connectivity     | `connectivity_plus` (offline banner + composer gating)                |
| i18n             | Custom `AppStrings` (EN / AR) + locale controller                     |

---

## Project structure

```
lib/
├── app.dart                          # MaterialApp.router + theme + locale wiring
├── main.dart                         # Bootstrap (Sentry, Dio, repositories, providers)
├── core/
│   ├── constants/                    # Route IDs, demo flags
│   ├── error/                        # AppFailure typed error envelope
│   ├── i18n/                         # AppStrings (EN / AR), locale cubit, remote i18n API
│   ├── logging/                      # AppLogger, AppBlocObserver, crash reporter bridge
│   ├── network/                      # Dio client, interceptors, endpoints, ApiException
│   ├── routing/                      # GoRouter config (singleton via `appRouter`), transitions
│   ├── state/                        # DataState envelope (idle/loading/success/failure)
│   ├── storage/                      # SecureTokenStore (Keychain / Keystore)
│   └── theme/                        # Color, gradients, radius, typography, SaqqarThemeExtension
├── features/
│   ├── account/                      # Profile + theme + language + sign out
│   ├── auth/                         # Sign in / Sign up + AuthCubit + bootstrap
│   ├── chat/                         # Chat screen + composer + tool activity + voice + share
│   │   ├── data/                     # ChatRepository, attachments, TranscribeApi
│   │   ├── view/                     # ChatScreen
│   │   ├── view_model/               # ChatCubit, RunningAgentsCubit, DeepThinkCubit
│   │   └── widgets/                  # Composer, message bubble, voice button, recording overlay
│   ├── conversations/                # List + search + swipe-archive + long-press menu
│   ├── inbox/                        # Approvals cubit + artifact downloader
│   ├── push/                         # Devices API (push registration scaffold)
│   ├── share/                        # Share intent bootstrap + intake service + picker overlay
│   ├── vault/                        # Credentials + projects + schema-driven form + test connection
│   └── demo/                         # Storybook-only demo data
├── shared/
│   ├── animations/                   # PulseDot, TypingDots — Reduce-Motion aware
│   ├── extensions/                   # context.saqqar, context.tr, context.text helpers
│   └── widgets/                      # PageScaffold, AmbientBackground, AppToast, GhostButton, etc.
android/                              # AndroidManifest (share intents, mic permission), signing
ios/                                  # Info.plist (mic, speech recognition, photo library)
docs/                                 # PUBLISHING_GUIDE, PRIVACY_POLICY, STORE_LISTING, RELEASE_NOTES_TEMPLATE
play-store-assets/                    # icon-512.png, feature-graphic.png
tool/                                 # generate_play_store_icon, generate_feature_graphic, etc.
```

---

## Design system

Visual language sourced directly from production `saqqaar.com/static/odoo_agent/app.css` — same palette, gradients, radii, and shadows as the web app.

**Brand**

- Cyan `#06B6D4` · Cyan Strong `#22D3EE` · Purple `#8B5CF6` · Navy `#1F3C88`
- Status: Success `#10B981` · Warning `#F59E0B` · Danger `#EF4444`

**Gradients**

- Primary CTA: `linear-gradient(135deg, #1F3C88, #06B6D4)`
- Vivid (avatars, gradient text): `linear-gradient(135deg, #06B6D4, #8B5CF6)`

**Surface tokens** are exposed via `SaqqarThemeExtension` and read through `context.saqqar.*` (`context.saqqar.brandCyan`, `context.saqqar.muted`, `context.saqqar.cardBorder`). Both Light and Dark themes are tuned independently with proper contrast.

**Geometry**

- Card radius 20, Button radius 12, Pill 999, Input 14, Modal 18, Bubble 16
- Touch targets ≥ 44 pt (iOS) / 48 dp (Android)

**Motion** — every decorative animation (pulse, scan-line, typing dots, scroll-to-bottom slide) checks `MediaQuery.disableAnimationsOf(context)` so OS-level Reduce Motion is honored.

**Typography** ships with the platform default — Roboto + Noto Sans Arabic on Android, San Francisco + SF Arabic on iOS. `google_fonts` was removed in 1.0.17 after testers on geo-blocked carriers hit CDN-fetch crashes; bundled brand fonts can be re-introduced via `assets/fonts/` if the visual difference matters.

To explore every primitive visually, run the app and navigate to **Account → Open Storybook**.

---

## Internationalization

- **English** (`en`) — default
- **Arabic** (`ar`) — full RTL: bubbles flip, search/chevron icons mirror, dropdowns reverse direction

Translations live in [`lib/core/i18n/app_strings.dart`](lib/core/i18n/app_strings.dart) — a single source of truth indexed by string keys. The schema-driven credential form uses `AppStrings.lookup(key)` so server-side keys (e.g. `apiKey`, `apiKeyHelp` from `/api/v1/credentials/schemas/`) resolve straight through.

Remote i18n (`/api/v1/i18n/<lang>.json`) is wired through `RemoteI18nApi` and ready to layer on top of `AppStrings` once we ship the merge logic.

Locale is persisted in `SharedPreferences` and follows system by default; users can override from **Account → Language**.

---

## Getting started

### Prerequisites

- [Flutter 3.35+](https://docs.flutter.dev/get-started/install)
- Dart 3.9+ (bundled with Flutter)
- **Android**: Android Studio Hedgehog+ with Android SDK 34+, JDK 17
- **iOS**: macOS + Xcode 15+, CocoaPods

### Install & run

```bash
git clone <repo-url>
cd saqqar_app
flutter pub get

# Optional but recommended: set the Sentry DSN so crashes report
# to the Digital Harbor Sentry org instead of dropping silently.
export SAQQAR_SENTRY_DSN="https://<dsn>@<org>.ingest.sentry.io/<id>"

# Run on a connected device or simulator
flutter run --release --dart-define=SAQQAR_SENTRY_DSN=$SAQQAR_SENTRY_DSN

# Pick a specific target
flutter run -d "iPhone 15"
flutter run -d emulator-5554
```

The app launches into `/chats`. Sign in with a real Saqqar account against `saqqaar.com`.

### Analyse & format

```bash
flutter analyze              # Lint + static analysis (must be clean before PRs)
dart format lib              # Auto-format (line length 80)
```

### Pre-commit hook (recommended)

A `pre-commit` hook lives in [`.githooks/`](.githooks/) that runs
`flutter analyze` and `dart format --set-exit-if-changed` on staged Dart
files. Install once per clone:

```bash
git config core.hooksPath .githooks
```

After that, every `git commit` blocks if analysis fails or formatting is stale.

---

## Build & release

### Android — Google Play

```bash
flutter build appbundle --release --dart-define=SAQQAR_SENTRY_DSN=$SAQQAR_SENTRY_DSN
# → build/app/outputs/bundle/release/app-release.aab
```

The release keystore lives at `android/saqqar-release.jks` (gitignored); credentials are in `android/key.properties` (also gitignored). See [docs/PUBLISHING_GUIDE.md](docs/PUBLISHING_GUIDE.md) for the full Play Store flow — staged rollout strategy, store listing, data safety form, App content checklist.

### iOS — App Store / TestFlight

See the iOS hand-off in the publishing guide. Quick path:

```bash
cd ios && pod install && cd ..
flutter build ipa --release --dart-define=SAQQAR_SENTRY_DSN=$SAQQAR_SENTRY_DSN
# → build/ios/ipa/saqqar_app.ipa
```

Upload with **Transporter** (App Store) or via `Xcode → Window → Organizer`.

Info.plist already declares the iOS permission strings (`NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`, `NSPhotoLibraryUsageDescription`).

### Version bump

Edit `pubspec.yaml` `version:` line — the `+N` build code must monotonically increase on every Play Console upload:

```yaml
version: 1.0.21+22   # <semver>+<build-code>
```

Also bump the Sentry release tag in [`lib/main.dart`](lib/main.dart) so error groups stay per-version.

---

## Backend integration

Every screen consumes real endpoints at `https://saqqaar.com/api/v1/`. The full contract lives in `SAQQAR_MOBILE_API.md` (and delta docs `SAQQAR_MOBILE_VOICE.md`, `SAQQAR_MOBILE_API_xmlrpc.md`) in the backend repo.

| Concern              | Endpoint                                                | Method   |
|----------------------|---------------------------------------------------------|----------|
| Auth                 | `/api/v1/auth/login/`, `/auth/me/`, `/auth/logout/`     | POST/GET |
| Conversations        | `/api/v1/conversations/`                                | GET/POST/PATCH/DELETE |
| Messages             | `/api/v1/conversations/<id>/messages/`                  | POST     |
| Attachments          | `/api/v1/conversations/<id>/attachments/`               | POST     |
| Voice transcription  | `/api/v1/transcribe/`                                   | POST     |
| Credentials          | `/api/v1/credentials/`                                  | GET/POST/PATCH/DELETE |
| Credential schemas   | `/api/v1/credentials/schemas/`                          | GET      |
| Credential test      | `/api/v1/credentials/test/`                             | POST     |
| Projects / envs      | `/api/v1/projects/`, `/api/v1/environments/<id>/`       | GET/POST/PATCH |
| Approvals            | `/api/v1/approvals/`, `/api/v1/approvals/<id>/decision/`| GET/POST |
| Artifacts            | `/api/v1/artifacts/`                                    | GET      |
| Shares               | `/api/v1/conversations/<id>/share/`, `/api/v1/shares/<token>/` | POST/GET |
| i18n                 | `/api/v1/i18n/<lang>.json`                              | GET      |
| Devices (push)       | `/api/v1/devices/`                                      | POST     |

**Auth**: opaque bearer token issued at sign-in. Dio's interceptor injects `Authorization: Bearer <token>` automatically and bridges 401s into `AuthCubit.handleUnauthorized()` so the router gate kicks the user to `/sign-in`.

**Error envelope**: all non-2xx responses return `{ "ok": false, "error": "<message>" }`. The ErrorInterceptor unwraps these into typed `ApiException` (kind: `network` / `timeout` / `badResponse` / `cancelled` / `unknown`).

**Polling cadence**: chat snapshots refresh every 1.5 s while the agent is running, 15 s when idle. Conversation lists and approvals refresh on tab focus + pull-to-refresh.

---

## Observability

**Sentry** is wired via `SentryFlutter.init` in `main.dart`. The DSN comes from `--dart-define=SAQQAR_SENTRY_DSN` so it never lands in source control. Local dev (no DSN) → SDK no-ops.

The `_shouldSkipSentry` filter drops noise so the dashboard only surfaces real bugs:
- Network / timeout / cancelled `ApiException`s (offline users, not bugs)
- 4xx responses (validation / business expected, not crashes)
- google_fonts CDN fetch errors (legacy, fonts removed in 1.0.17)

Errors caught by repositories and cubits are bridged into Sentry via `AppLogger.setCrashReporter`. Uncaught Flutter errors and PlatformDispatcher errors both chain through Sentry's handler before our logger.

Release tag: `saqqar@<semver>+<build>` (matches pubspec) — groups crashes per version in the Sentry UI.

---

## Contributing

Internal team workflow:

1. Branch from `saqqar-mostafa` with a descriptive name (`feature/voice-input`, `fix/share-intent-flash`).
2. Keep changes scoped — one feature or fix per PR.
3. Run `flutter analyze` and ensure it returns "No issues found" before pushing.
4. Avoid hard-coded strings — every user-facing label must go through `AppStrings` (or the schema-driven `lookup(key)` path).
5. New colors? Add to [`app_colors.dart`](lib/core/theme/app_colors.dart) **and** the `SaqqarThemeExtension`. Don't sprinkle `Color(0x…)` literals in widgets.
6. New screens? Use `PageScaffold` (top-level tab) or `Scaffold` + `AmbientBackground` (auth / hero). Don't reinvent the page shell.
7. Cubit lifecycle: every cubit overrides `emit` with an `isClosed` guard so emit-after-close never crashes during sign-out / route teardown. Follow the same pattern in new cubits.
8. Test on both Light and Dark themes, and both English (LTR) and Arabic (RTL) before requesting review.
9. Bump `pubspec.yaml` version + the Sentry release tag in `main.dart` for every Play Store / App Store upload.

---

## License

Proprietary © Digital Harbor. All rights reserved.

> The visual language and brand assets in this repository (logos, color palette, gradients) are the property of Digital Harbor and may not be redistributed without permission.
