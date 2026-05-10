# Saqqar Mobile — Odoo Operations Copilot

[![Flutter](https://img.shields.io/badge/Flutter-3.35-02569B?logo=flutter)](https://flutter.dev) [![Dart](https://img.shields.io/badge/Dart-3.9-0175C2?logo=dart)](https://dart.dev) [![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20Android-lightgrey)](#) [![Status](https://img.shields.io/badge/status-foundation--ready-yellow)](#status)

The native mobile companion to [saqqaar.com](https://saqqaar.com) — a chat-driven AI agent for operating Odoo ERP systems. Users sign in, open a conversation, type a request in natural language, and Saqqar uses live tools (Odoo XML-RPC, PostgreSQL, server shell, GitHub) to diagnose, report, and act — with every risky change gated behind explicit approval.

This Flutter client mirrors the web product's behavior on a phone: per-user encrypted credential vault, per-conversation credential toggles, approval flows for destructive actions, and tool-call transparency.

> **Product:** Saqqar  ·  **Domain:** saqqaar.com (double-a)  ·  **Owner:** Digital Harbor

---

## Table of contents

- [Status](#status)
- [Screens](#screens)
- [Tech stack](#tech-stack)
- [Project structure](#project-structure)
- [Design system](#design-system)
- [Internationalization](#internationalization)
- [Getting started](#getting-started)
- [Build & release](#build--release)
- [Backend prerequisites](#backend-prerequisites)
- [Roadmap](#roadmap)
- [Contributing](#contributing)

---

## Status

**Foundation-ready demo.** The visual layer, navigation, and reactive state plumbing are complete and run end-to-end against in-memory demo data. Real API integration, token-based auth, and streaming responses are blocked on backend work (see [Backend prerequisites](#backend-prerequisites)).

What works today:

- ✅ Five-tab bottom navigation (Chats / Vault / Inbox / Files / Account)
- ✅ Conversations list with search, archive filter, pagination, and pull-to-refresh
- ✅ Chat screen with grouped messages, typing indicator, scroll-to-bottom, long-press copy, tool-activity cards, attachments
- ✅ Credential vault (Add / Edit / Delete) with schema-driven form, per-kind accents, and **— None —** option
- ✅ Inbox with live approval flow — approve/reject updates the bottom-nav badge in real time
- ✅ Action Center shared between Chat sheet and Inbox via Riverpod
- ✅ Files screen with kind-specific accent colors
- ✅ Account with theme (Light / Dark / System) and language (English / Arabic) controls
- ✅ Dark + Light themes with smooth transitions
- ✅ English + Arabic with full RTL mirroring (Tajawal font swap)
- ✅ Welcoming empty state on new chats with one-tap suggestion prompts
- ✅ Reduce Motion respected on every custom animation

What's stubbed (needs backend):

- ⏳ Real authentication (currently `test` / `test` opens the workspace)
- ⏳ HTTP client wired to live endpoints (Dio configured but not consumed)
- ⏳ Streaming assistant responses (SSE / WebSocket transport TBD)
- ⏳ Push notifications for approvals (FCM / APNs)
- ⏳ Real credential schemas from `GET /api/credentials/schemas/`

---

## Screens

| Tab     | Screen              | What it does                                                              |
| ------- | ------------------- | ------------------------------------------------------------------------- |
| Chats   | Conversations list  | All conversations, with search / archived filter / row menu / pagination  |
|         | Chat                | Welcome state, message stream, composer, tool activity, status strip      |
| Vault   | Credential vault    | Saved bundles by kind (XML-RPC, Postgres, Shell, GitHub) with schema form |
| Inbox   | Action Center       | Agent requests (e.g., "provide Postgres credentials")                     |
|         | Pending approvals   | Destructive actions awaiting consent — approve / reject updates badge    |
|         | History             | Recently approved / rejected items                                        |
| Files   | Artifacts           | Excel, CSV, logs, screenshots — kind-colored, downloadable                |
| Account | Profile + settings  | Hero card + stats + theme + language + sign out                           |
| Auth    | Sign-in             | Token-based login (currently demo). Brand hero on tablet / web widths    |

Plus the **Storybook** screen (long-press into Account) — a foundation-only inventory of every primitive (cards, buttons, pills, inputs, etc.) for visual QA.

---

## Tech stack

| Layer            | Choice                                                     |
| ---------------- | ---------------------------------------------------------- |
| Framework        | Flutter 3.35 / Dart 3.9                                    |
| State management | [Riverpod](https://riverpod.dev) (`flutter_riverpod`)      |
| Routing          | [go_router](https://pub.dev/packages/go_router) (shell + nested) |
| Networking       | [Dio](https://pub.dev/packages/dio) with interceptors      |
| Secure storage   | `flutter_secure_storage` (keychain / Keystore)             |
| Preferences      | `shared_preferences`                                       |
| Typography       | `google_fonts` — Inter (Latin) + Tajawal (Arabic)          |
| Iconography      | [Lucide](https://lucide.dev) via `lucide_icons_flutter`    |
| i18n             | `intl` + custom locale controller                          |

---

## Project structure

```
lib/
├── app.dart                   # MaterialApp.router + theme + locale wiring
├── main.dart                  # Bootstrap (SharedPreferences override)
├── core/
│   ├── constants/             # Technical constants (route IDs, demo flags)
│   ├── i18n/                  # AppStrings (EN / AR), locale controller, delegate
│   ├── network/               # Dio client, interceptors, endpoint catalog
│   ├── routing/               # GoRouter config, route names, transitions
│   ├── storage/               # Secure token store (keychain / Keystore)
│   └── theme/                 # Color, typography, gradients, radius, theme ext.
├── features/
│   ├── account/               # Profile + theme + language + sign out
│   ├── auth/                  # Sign-in screen
│   ├── chat/                  # Chat screen + composer + tool activity
│   ├── conversations/         # Conversations list with search & pagination
│   ├── files/                 # Artifacts list
│   ├── inbox/                 # Approval flow + Riverpod controller
│   │   ├── presentation/
│   │   └── state/             # approvals_controller.dart — shared state
│   ├── vault/                 # Credentials list + schema-driven add/edit sheet
│   ├── demo/                  # In-memory demo data (replace with API later)
│   └── storybook/             # Visual QA inventory
├── navigation/
│   └── home_shell.dart        # Bottom tab bar with reactive badge
└── shared/
    ├── animations/            # PulseDot, TypingDots — Reduce-Motion aware
    ├── extensions/            # context.saqqar, context.tr helpers
    └── widgets/               # GlassCard, ActionCard, AppToast, etc.
```

---

## Design system

Visual language sourced directly from production `saqqaar.com/static/odoo_agent/app.css` — same palette, gradients, radii, and shadows as the web app.

**Brand**

- Cyan `#06B6D4`  ·  Cyan Strong `#22D3EE`  ·  Purple `#8B5CF6`  ·  Navy `#1F3C88`
- Status: Success `#10B981`  ·  Warning `#F59E0B`  ·  Danger `#EF4444`

**Gradients**

- Primary CTA: `linear-gradient(135deg, #1F3C88, #06B6D4)`
- Vivid (avatars, gradient text): `linear-gradient(135deg, #06B6D4, #8B5CF6)`

**Surface tokens** are exposed via a `SaqqarThemeExtension` and read through `context.saqqar.*` (e.g. `context.saqqar.brandCyan`, `context.saqqar.muted`, `context.saqqar.cardBorder`). Both Light and Dark themes are tuned independently with proper contrast.

**Geometry**

- Card radius 20, Button radius 12, Pill 999, Input 14, Modal 18, Bubble 16
- Touch targets ≥ 44 pt (iOS) / 48 dp (Android)

**Motion** — every decorative animation (pulse, scan-line, typing dots, scroll-to-bottom slide) checks `MediaQuery.disableAnimationsOf(context)` so OS-level Reduce Motion is honored.

To explore every primitive visually, run the app and navigate to **Account → Open Storybook**.

---

## Internationalization

- **English** (`en`) — default, Inter typeface
- **Arabic** (`ar`) — Tajawal typeface, full RTL: bubbles flip, search/chevron icons mirror, switches reverse direction

Translations live in [`lib/core/i18n/app_strings.dart`](lib/core/i18n/app_strings.dart) — a single source of truth indexed by string keys. To add a string, add it once to `_en` and once to `_ar`, then expose a getter at the top of the class.

Locale is persisted in `SharedPreferences` and follows system by default; users can override from **Account → Language**.

---

## Getting started

### Prerequisites

- [Flutter 3.35+](https://docs.flutter.dev/get-started/install)
- Dart 3.9+ (bundled with Flutter)
- Xcode 15+ (iOS) / Android Studio Hedgehog+ with Android SDK 34+ (Android)

### Install & run

```bash
git clone <repo-url>
cd saqqar_app
flutter pub get

# Run on a connected device or simulator
flutter run

# Or pick a specific target
flutter run -d chrome        # Web
flutter run -d "iPhone 15"   # iOS Simulator
flutter run -d emulator-5554 # Android emulator
```

The demo opens at `/chats`. To exercise the sign-in flow, navigate to `/sign-in` — any credentials let you in (the auth controller is currently a no-op).

### Analyse & format

```bash
flutter analyze              # Lint + static analysis (must be clean before PRs)
dart format lib              # Auto-format (line length 80)
```

---

## Build & release

### Android

```bash
flutter build apk --release         # Single APK
flutter build appbundle --release   # Play Store bundle
```

Artifacts land in `build/app/outputs/`. Sign with your release keystore (see `android/key.properties`).

### iOS

```bash
flutter build ios --release
```

Open `ios/Runner.xcworkspace` in Xcode for archive + TestFlight.

### Web (preview only)

```bash
flutter build web --no-tree-shake-icons
```

> Web is supported for design preview; production deploys ship to iOS / Android.

---

## Backend prerequisites

The mobile client expects these endpoints once the backend lands them. Until then, the app runs against `lib/features/demo/saqqar_demo_data.dart`.

| Concern                  | Endpoint                                                  | Method     |
| ------------------------ | --------------------------------------------------------- | ---------- |
| Token-based auth         | `/api/auth/login/`                                        | `POST`     |
| Conversations            | `/api/conversations/?include_archived=1`                  | `GET`      |
| Conversation detail      | `/api/conversations/<id>/`                                | `GET`      |
| Send message             | `/api/conversations/<id>/messages/`                       | `POST`     |
| Upload attachment        | `/api/conversations/<id>/attachments/`                    | `POST`     |
| Credentials list         | `/api/credentials/`                                       | `GET/POST` |
| **Credential schemas**   | `/api/credentials/schemas/`                               | `GET`      |
| Per-chat credential togg | `/api/conversations/<id>/credentials/toggle/`             | `POST`     |
| Approval decision        | `/api/approvals/<id>/decision/`                           | `POST`     |
| Share conversation       | `/api/conversations/<id>/share/`                          | `POST`     |
| Shared transcript        | `/share/<token>/`                                         | `GET`      |
| Push registration        | `/api/push/register/` (TBD)                               | `POST`     |
| i18n strings             | `/api/i18n/<lang>.json` (recommended for parity with web) | `GET`      |

**Critical contracts**

1. **The credential form MUST be schema-driven** — never hard-code fields. Fetch the schema for each kind from `GET /api/credentials/schemas/` and render dynamically (see [`lib/features/demo/saqqar_demo_data.dart`](lib/features/demo/saqqar_demo_data.dart) for the expected shape).
2. **Streaming**: the assistant typing indicator implies token-by-token rendering. Backend should expose SSE or WebSocket — to be confirmed before chat is wired to live.
3. **Approval gating**: destructive actions return HTTP `202` with an `approval_id`; mobile retries once the user has approved via `POST /api/approvals/<id>/decision/`.

---

## Roadmap

The §18 sign-off checklist from the design spec, with current state:

- [x] Token-strategy decision (webview fallback → token endpoint blocker logged)
- [x] All five tab screens implemented in dark + light themes
- [x] LTR + RTL parity across every screen
- [x] Schema-driven Add Credential sheet (UI ready, awaits real schemas API)
- [x] Approval flow handles all five action types (UI complete, awaits decision API)
- [x] Tool-call (server-activity) bubbles render
- [x] Welcoming empty state with suggestion prompts
- [x] Attachment chip variants (image / file)
- [x] Empty / loading / error / offline states scaffolded
- [x] Touch targets ≥ 44 pt / 48 dp
- [x] Reduce Motion respected on every custom animation
- [ ] Real auth wired to backend
- [ ] Streaming assistant text with cursor + scan-line
- [ ] Per-conversation credential toggle wired to API
- [ ] VoiceOver / TalkBack labels audit
- [ ] Dynamic Type / font scaling audit
- [ ] App icon + splash from `light-mode-logo.png` / `dark-mode-logo.png`
- [ ] Widget tests for primary flows
- [ ] Push notifications (if in v1 scope)

---

## Contributing

Internal team workflow:

1. Branch from `main` with a descriptive name (`feature/chat-streaming`, `fix/vault-empty-state`).
2. Keep changes scoped — one feature or fix per PR.
3. Run `flutter analyze` and ensure it returns "No issues found" before pushing.
4. Avoid hard-coded strings — every user-facing label must go through `AppStrings`.
5. New colors? Add to [`app_colors.dart`](lib/core/theme/app_colors.dart) **and** the `SaqqarThemeExtension`. Don't sprinkle `Color(0x…)` literals in widgets.
6. New screens? Use `PageScaffold` (top-level tab) or `Scaffold` + `AmbientBackground` (auth / hero). Don't reinvent the page shell.
7. Test on both Light and Dark themes, and both English (LTR) and Arabic (RTL) before requesting review.

---

## License

Proprietary © Digital Harbor. All rights reserved.

> The visual language and brand assets in this repository (logos, color palette, gradients) are the property of Digital Harbor and may not be redistributed without permission.
