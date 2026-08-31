# Changelog

All notable changes to the Saqqar mobile client are documented here. The
format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
the project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed — 2026-08-31

Reported by the team: Saqqar asks for permission to modify something and the
approval card never appears — first as a general report, then narrowed to "it
works on Android but not on iPhone". Four defects, none of them in the card
itself, which was covered three times over and rendered correctly given the
data. The path from `snapshot.approvals` to the screen was what had never been
tested.

- **A chat with no visible messages hid every pending approval.** The inline
  approval cards live inside the message list, and the list is only built when
  the transcript has something to show — an empty one renders suggestion chips
  instead. `isVisibleMessage` drops every `tool` row and every empty-content
  assistant row, which is most of what a run emits, so a turn that goes
  straight to tool calls and stops at an approval gate had a decision waiting
  and nothing visible to render it beside. The agent sat blocked with the one
  control that releases it never drawn, under a screen inviting the user to
  start a conversation that was already running. **This is almost certainly the
  "iPhone" report**: whether a turn produced a visible row depends on the task,
  not the device, so two testers doing different things see different results.
  A sweep of `TargetPlatform.iOS` × Arabic × Reduce Motion × iPhone safe-area
  insets × the smallest supported screen found no platform difference at all.
- **One malformed row took the whole snapshot down.** The list decode claimed
  in its own comment to skip a bad element and did not — `whereType` only
  filters non-maps, so a row whose `id` is missing or numeric threw out of
  `ConversationSnapshot.fromJson`. On the poll path that throw is caught and
  logged as a warning nobody reads, so a single bad approval froze the entire
  chat: no card, no new messages, no error, on every tick for as long as the
  row was pending. Every list is now element-tolerant.
- **A response that never mentioned approvals was read as "none pending".**
  After the first tick every poll asks `?since=`, so a deployment whose delta
  omits the key could raise an approval, land it in one snapshot, and have the
  tick 1.5 s later erase it — permanently, since nothing asked for a full
  snapshot again. Absent key and `approvals: []` are now distinguished; an
  explicit empty list still clears the card immediately, so a decision made
  here, on the web, or by a batch scope drops off exactly as fast as before.
- **`ChatCubit.refresh()` fetched a delta.** Every caller is a user action that
  changed something the message stream does not carry — an approval decided, an
  environment bound — so it confirmed each one by asking the single question
  none of them had. It now asks without `?since=`.
- **An empty non-delta window erased the transcript.** `overlaps` evaluates to
  `0 < 0` for a zero-message response, which fell through to "adopt verbatim"
  and replaced a loaded conversation with an empty one.

### Tests — 2026-08-31

- `approval_delivery_test.dart` — the wire-to-state half: malformed rows,
  absent vs. empty `approvals`, `refresh()`'s request shape, the empty-window
  guard. Seven of its thirteen cases fail against the pre-fix code.
- `approval_inline_render_test.dart` — the state-to-screen half, on the real
  `ChatScreen`: the iPhone matrix above, the empty-transcript state, and the
  Approve / Reject taps driven through to the decision POST and the card
  leaving the screen.

### Fixed — 2026-08-12

- **Flinging to the top of a long chat parked you against a dead edge.** The
  fling outran the fetch: by the time the page landed the reader was already at
  `extentBefore == 0`, and the row the correction re-anchors against had been
  culled by the lazy list — so no correction applied and the list did not move
  at all, which is exactly what "it froze" looks like. The only way out was to
  scroll down and back up, which nobody discovers. The lane now eases down off
  the edge, which puts the freshly revealed messages above the reader and
  re-arms the load trigger that had latched off.
- **…and the first version of that fix threw the reader to the newest
  message.** Reported immediately. Two separate causes, both found by measuring
  on a signed-in device rather than reasoning about it. The nudge clamped its
  target to `maxScrollExtent`, so whenever the rendered transcript was shorter
  than the bump — often, since a page reveals a bounded number of rows — the
  clamp resolved to the very bottom. The ceiling is now
  `maxScrollExtent - viewportDimension`, which keeps a full screen of history
  below the landing point by arithmetic rather than by hope. Separately, a
  `prependGrowthTarget` correction was **removed outright**: its premise, that
  growth in `maxScrollExtent` is the height inserted above, is false —
  `ListView.builder` *estimates* its extent and revises that estimate in both
  directions. One burst of flings measured `3617 → 7251 → 5494 → … → 181096`,
  and on the last step it computed a jump of 152,048 px. The same capture
  showed the precise row-anchored correction firing **zero** times under a fast
  fling, so the honest position is that no correction is available in that case.
  Verified over 25 rapid flings: no growth correction fires, every nudge lands
  at the same offset regardless of the overscroll it was sampled at, and paging
  reaches the true start of the conversation.
- **Three overflows in the environment card of `ProjectDetailSheet`**, at
  320 px. They had gone unseen because the sheet was never actually rendering
  its data: `VaultCubit.load()` is called from exactly one place in the app,
  `VaultScreen.initState`, and the sweep pumped the sheet standalone against
  an idle cubit — so twenty layouts per sheet were measured on an empty shell,
  which cannot overflow. With the fixture loaded, all three appeared at once:
  the env-name field and the Live / Read-only checkboxes shared a `Row`
  (15 px — `Expanded` shrinks to zero but no further, and the two labels alone
  are wider than the card); Open and Delete were a `Row(mainAxisSize: min)`
  inside a `Wrap`, so the group could move to a second run but never split
  (2.8 px); and `_FlagCheckbox` gave its own label unbounded width, so one
  checkbox overflowed by 14 px in Arabic at 1.4× text. Name now takes its own
  line, both button and flag groups flow, and the label is `Flexible` — it
  wraps rather than ellipsizes, because "قراءة فق…" leaves the user guessing
  what they are about to toggle on a live Odoo instance.

### Changed — 2026-08-12

- **Every responsive sweep now proves its fixture rendered.** Ten of the
  twenty-four swept surfaces asserted only "no layout exception", which an
  empty screen satisfies trivially — the failure mode that had already hidden
  a 126 px overflow behind `PricingScreen`'s error state for months. Content
  proofs added for Pricing, Usage, the three Vault sheets, Data Explorer,
  Meetings, `AppLaunchDialog` and `EnvironmentMultiSelectSheet`; Data Explorer
  and Meetings are additionally driven into their populated states, since both
  open on a form and everything worth measuring exists only after the user
  acts.
- **All brand hex now lives in `app_colors.dart`.** The invariant guarding this
  exempted the whole `core/theme/` directory, and five literals had settled
  into the blind spot — four shadow tints in `SaqqarThemeExtension` and the
  code plate in `AppTheme` — while `app_colors.dart` claimed in its own doc
  comment to be the single home for them. The guard now names that one file,
  and was verified to fail against a reintroduced literal.

- **Turning Task prep on in one chat turned it on in every chat.** The second
  half of the same report. The toggle renders as
  `conversation.taskPrep ?? deviceDefault`, and the flip handler wrote *both*
  the PATCH and that device-wide default — so raising the default re-rendered
  every conversation the server still had no value for, which (the backend
  keeps the column nullable and defaulted to `null`) is every conversation
  nobody has flipped yet. An existing chat now writes only its own
  conversation; the device default is written solely for a chat that does not
  exist server-side yet, where there is nothing to PATCH and it is what the
  first send carries. Verified on a real device: conversations now hold
  different values simultaneously. Guarded by a `source_invariants_test` rule
  that was rewritten after the first attempt passed against a deliberately
  reintroduced leak.
- **The Task-prep toggle never synced to the web.** Reported twice by the user,
  and the asymmetry was the clue: Auto-approve sits in the same row and synced
  every time. `_setTaskPrep` PATCHed only when `conversation.task_prep` was
  already non-null, but the backend ships the field nullable with every
  existing row reset to `null` — a deadlock, because the app could then never
  give the field its first value. Only the web could, and once it had, mobile
  started syncing, which is why it read as intermittent rather than broken.
  Confirmed on a real device against production (`"task_prep": null` in the
  live snapshot). A flip now PATCHes on the same terms as auto-approve;
  reading still prefers the server's value and falls back to the device
  preference on `null`. Pinned by `test/task_prep_sync_test.dart`, verified to
  fail against the old code.

- **Voice Support filed empty tickets.** `POST /voice-support/ticket/` was
  sent `title` + `priority` only. Those are the two fields that map onto Odoo
  columns; the ticket *description* is composed server-side from the draft
  body, so a filed ticket carried a subject line and nothing else — and the
  user was told support had been contacted. The whole draft now goes on the
  wire, success requires `ok && ticket_id`, and the `project.task` fallback is
  reported as a task rather than a helpdesk ticket. The draft's `diagnosis`
  field is rendered too; nothing had ever read it.
- **Arabic iPhones opened the app in English.** `Info.plist` declared no
  `CFBundleLocalizations`, so iOS filtered Arabic out of the preferred-language
  list Flutter reads — every first launch on an Arabic device defaulted to
  English until the user found the in-app switch. Android was never affected.
- **iOS permission prompts were English-only.** Added
  `en.lproj`/`ar.lproj` `InfoPlist.strings` (camera / microphone / photos /
  Face ID). These are drawn by the OS before any Saqqar screen exists, so
  `AppStrings` cannot reach them. Both are wired into `project.pbxproj` as an
  `InfoPlist.strings` variant group in Copy Bundle Resources with `ar` in
  `knownRegions` — a fresh clone builds them with no Xcode step.
- **An iPhone photo was three different things at once.** Five places
  classified file extensions independently and disagreed about HEIC: the
  composer labelled it "HEIC", the sent message drew it as a picture, and the
  viewer refused it. One table now (`FileKinds`), which also knows `bmp`,
  `heic` and `heif` everywhere.
- **A failure envelope on the transcript read parsed as an empty chat.**
  `GET /conversations/{id}/` is read as plain text so it can be decoded off
  the UI isolate, which bypasses the interceptor that catches
  `200 {"ok": false}` — the chat opened blank with the server's explanation
  discarded. Checked after the decode now.
- **Usage rows overflowed at maximum text size.** The plan card's `Row` gave
  the count an unbounded width; at 320 px × 1.4× text in Arabic it measured
  wider than the lane. Now uses `TitleTrailingRow`, which caps the accessory.
- **Native sign-in failures read "Something went wrong."** Google/Apple
  failures travelled as an untyped exception carrying English text, so all
  three landed on the generic copy — including the one case where retrying can
  never work. Now a typed `SocialSignInFailure` with copy that names the way
  out, in both languages.

### Added — 2026-08-12

- **`Accept-Language` on every request**, from the live language preference
  (re-read per call, so the in-app switch takes effect immediately). Retires
  the need for the client-side Arabic plan table and lets the backend localize
  its `error` strings for Arabic readers.
- **`env_id` on filed support tickets**, carried from the conversation the
  user opened support from, so the ticket lands in the database they were
  actually asking about.
- **`test/platform_manifest_test.dart`** — pins the Android manifest and iOS
  Info.plist/entitlements against what the Dart code actually does:
  permissions, usage strings, production APNs, deep-link hosts, no-backup
  posture, and the localization list.
- **Full API contract coverage.** The hostile-response sweep went from 50 of
  89 client methods to all of them — including the entire OTP entry path,
  every credential write and every project/environment mutation.

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
