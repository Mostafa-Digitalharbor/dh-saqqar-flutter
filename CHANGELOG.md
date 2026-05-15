# Changelog

All notable changes to the Saqqar mobile client are documented here. The
format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
the project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Skeleton loading** for the Conversations / Vault / Files lists. Animated
  shimmer matches each row's silhouette and fades into the real list when the
  fetch completes. New: `SkeletonBlock`, `ConversationCardSkeleton`,
  `CredentialRowSkeleton`, `ArtifactCardSkeleton`.
- **Offline banner** wired to `connectivity_plus`. Sticky red strip slides in
  at the top of every `PageScaffold` (and the chat screen) when the device
  loses connectivity. Chat composer's send button disables in lockstep so
  the user can't queue requests that would silently fail.
- **Welcoming Conversations empty state** with a vivid Saqqar avatar, headline,
  body copy, and a "New conversation" CTA. Replaces the generic placeholder.
- **Connectivity controller** (`ConnectivityController` + Riverpod provider)
  that any widget can watch to react to online / offline state.
- **PR template** at `.github/pull_request_template.md` with theme + RTL +
  test plan checklist.
- **Issue templates** for bug reports and feature requests.
- **Pre-commit hook** at `.githooks/pre-commit` that runs
  `flutter analyze --no-fatal-infos` plus `dart format --set-exit-if-changed`
  on staged Dart files. Installed via `git config core.hooksPath .githooks`.
- New i18n strings: `offline_title`, `offline_body`, `ask_saqqar_anything`,
  `remove_attachment` (EN + AR).
- New icon: `AppIcons.cloudOff`.

### Changed

- `ChatSendButton` now accepts a nullable `onPressed`; passing `null` renders
  a disabled muted state used by the composer when offline.
- `PageScaffold` body is now a `Column` so the `OfflineBanner` can sit above
  the scrollable content without consuming the refresh gesture.

### Tests

- 17 widget tests still passing after the connectivity + skeleton additions.

## [0.2.0] — 2026-05-11 (foundation-ready demo)

### Added

- **Full widget refactor** — every screen's private widgets extracted into
  dedicated `features/<x>/widgets/` folders with barrel exports
  (`widgets.dart`). Chat alone went from a 1990-line monolith to a 530-line
  orchestrator + 22 reusable widgets.
- **Inbox approval flow** with shared `ApprovalsController` (Riverpod
  Notifier) tracking both decisions and dismissed agent requests. The
  bottom-nav badge, chat sheets, and inbox screen all subscribe to the
  same source of truth.
- **Typing indicator** (`TypingDots`) — staggered three-dot pulse shown
  while the assistant is composing a reply. Respects Reduce Motion.
- **Long-press to copy** on any chat bubble — copies the message text and
  surfaces a confirmation toast.
- **Pull-to-refresh** on Conversations / Vault / Files lists via
  `PageScaffold.onRefresh`.
- **Scroll-to-bottom FAB** in the chat — fades in when the user has scrolled
  ≥ 240 px away from the latest message.
- **Welcome chat state** for empty conversations: large Saqqar avatar,
  active-credential pill, and three localised suggestion prompts.
- **Credential "— None —" option** in the chat credential picker so the
  agent can request credentials inline when needed.
- **GitHub Actions CI** (`.github/workflows/ci.yml`) — analyze + format
  check + tests + debug APK artifact on every push.
- **Smoke tests** for app boot, approvals state, and primitive layout
  resilience (4 tests). Plus 13 widget tests covering the extracted
  primitives (chat avatar, mini switch, credential chip, scroll-down
  button, attachment chip, message bubble, meta dot, conversation card,
  credential row, artifact card).
- **`.editorconfig`** for consistent indentation across editors.
- **`flutter_launcher_icons` + `flutter_native_splash`** dev dependencies
  with config pointing at `assets/img/light-mode-logo.png` and
  `assets/img/dark-mode-logo.png`. Run the generators once the logo files
  are dropped in.
- New i18n strings for the chat suggestion prompts (`suggest_user_count`,
  `suggest_export_users`, `suggest_tail_log`) in EN + AR.
- Shared widgets barrel at `lib/shared/widgets/widgets.dart`.

### Changed

- **Visual overhaul of the chat screen** — removed the heavy context bar,
  the timeline divider, the uppercase role labels (`YOU` / `SAQQAR`), and
  the ambient cyan/purple blobs from the background. Replaced with a clean
  minimal layout: grouped consecutive messages share an avatar, time shows
  only on the last message of a group, and tool activity collapses to a
  one-line header that expands on tap.
- **Approval cards** redesigned — neutral surface + 4-px amber start-side
  stripe + small amber icon plate, instead of the previous full amber wash.
- **Auto-approve toggle** uses brand cyan (not amber) when on.
- `ConversationsScreen` action menu re-organised; conversation rows render
  archived items at 70% opacity with an amber "archived" chip.
- **Stricter `analysis_options.yaml`** — `prefer_const_constructors`,
  `unawaited_futures`, `use_decorated_box`, `prefer_final_locals`, plus
  strict casts / inference / raw types.
- All hard-coded English strings in chat suggestions moved to `AppStrings`.

### Fixed

- Bottom-sheet overflow in the credential picker (`isScrollControlled: true`
  + `ConstrainedBox(maxHeight: 0.85 * screenHeight)` + `Flexible` +
  `SingleChildScrollView`).
- Cyan glow shadows on avatars / send button removed — they read as yellow
  halos on some OLED displays.
- Live status dot's green glow removed for the same reason.

## [0.1.0] — Initial scaffolding

### Added

- Initial Flutter app skeleton: GoRouter, Riverpod, theme controller,
  locale controller, Dio client with auth interceptor.
- Five-tab bottom nav: Chats, Vault, Inbox, Files, Account.
- Demo data layer at `lib/features/demo/saqqar_demo_data.dart`.
- Saqqar theme extension with Light / Dark variants and full RTL support
  (English + Arabic via Inter + Tajawal).
- Shared widgets: GlassCard, PrimaryButton, GhostButton, DangerButton,
  AppIconButton, AppTextField, AppToast, StatusPill, MiniChip,
  PaginationBar, SearchAndFiltersBar, EmptyState, FeatureIntroCard,
  ActionCard, CredentialCard, FadeSlideIn, PulseDot.
- Storybook screen at `/account → Open storybook` for visual QA.
