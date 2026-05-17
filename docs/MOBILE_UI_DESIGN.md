# Saqqar Mobile — UI Design Proposal

> A fresh design for a native mobile companion to **saqqaar.com**.
> Treat this as if no mobile app exists yet — what would we build from scratch in 2026, given the web product as the reference, knowing the brand, the audience, and the workflows?

---

## 0 · Context

**The product** — Saqqar is an Odoo operations copilot. A user talks to it in natural language; the agent inspects records, runs SQL, generates Excel/PDF/Word reports, reads GitHub, executes shell commands. Every risky action passes through an approval gate. Credentials live in a per-user vault and are either used for one turn or memorised after an explicit approval.

**The audience** — Odoo admins, DevOps engineers, customer-success leads at Digital Harbor. They are technical, time-poor, and operate against live production systems. Trust matters more than speed.

**The web** — desktop-grade, dense, three-pane layout: sidebar + chat + inbox drawer. Modal-heavy for vault management. Designed for sustained desk sessions.

**The phone is different** — single-pane, thumb-driven, interrupted sessions, often on the move (between meetings, during an outage, while reviewing an alert from Slack). The mobile experience should respect that the user opened the app for a *specific reason* — not to browse.

---

## 1 · Design principles

The five constraints every decision is measured against. When a tradeoff arises, principle 1 beats 2, beats 3, etc.

### 1.1 — Approval is sacred
The user came here to give the agent permission. Pending approvals never live more than one tap from the home surface, never get hidden behind a tab, and never look decorative. A red dot on a bottom-tab icon is not enough — surface the count, the action, and the consequence.

### 1.2 — One thumb, one hand
75 % of mobile sessions are one-handed. Primary actions live in the bottom third. Destructive actions get a confirmation step. Long-press is an enhancement, never the only way.

### 1.3 — Chat is the workspace
Unlike a SaaS dashboard, the chat is not one of many surfaces — it *is* the product. The app should feel like Claude or ChatGPT mobile, not like Slack or Linear. Other surfaces (vault, account, history) are escape hatches, not destinations.

### 1.4 — Live state is honest
The agent runs tools. Tools take time. The user must always know what is happening, what just finished, and what they are waiting for. Spinners without context are forbidden. "Saqqar is thinking..." with no tool name is forbidden. Streaming responses preferred over batched.

### 1.5 — Mobile is bilingual by default
EN + AR with full RTL. Arabic is not a translation step — it is a parallel design target. Typography (Tajawal + Inter), tracking, line-height, and layout direction are all rechecked per locale.

---

## 2 · Design language

The web hands us a fully-formed brand. Mobile should feel like the same product, not a different app that happens to share a logo. **All tokens below are lifted from `static/odoo_agent/app.css` and adapted for native.**

### 2.1 — Colour palette

```
DARK MODE (PRIMARY — the brand lives here)

  bg                  #030712   ████  near-black navy, app background
  surface             #111827   ████  cards, sheets, AppBar
  surface-2           #1E293B   ████  input fills, raised cards
  surface-3           #273349   ████  hover/active state

  text                #F8FAFC   ████  primary text
  muted               #94A3B8   ████  secondary text, hints
  faint               rgba(.30) ░░░░  disabled, dividers

  border              #1E293B   ────  default border
  hairline            rgba(.10) ────  separators

  brand-cyan          #06B6D4   ████  primary accent, CTAs, links
  brand-cyan-strong   #22D3EE   ████  hover, focus rings
  brand-purple        #8B5CF6   ████  secondary accent, deep-think, AI moments
  brand-navy          #1F3C88   ████  brand mark fill, marketing surfaces

  success             #10B981   ████  approvals granted, env online
  warning             #F59E0B   ████  pending approval, live env caution
  danger              #EF4444   ████  rejected, destructive confirm

  brand-gradient      135° → cyan → purple
                      (used on: send button, primary CTAs, brand mark)


LIGHT MODE (parity, less hero)

  bg                  #F8FAFC   ████
  surface             #FFFFFF   ████
  surface-2           #F1F5F9   ████
  text                #0F172A   ████
  muted               #64748B   ████
  brand-cyan          #06B6D4   ████   (same — brand colour does not invert)
  brand-purple        #8B5CF6   ████
```

**Why these:**
- Dark default reflects the user's environment — engineers run dark terminals, dark IDEs, dark Slack. Light is a comfort option, not the primary.
- Cyan + purple gradient is the brand fingerprint. Use it sparingly (CTAs, brand mark, the live "agent is working" pulse) so it stays meaningful.
- Warning amber > danger red for pending approvals, because pending ≠ wrong. Red is reserved for rejected outcomes and destructive confirmations.

### 2.2 — Typography

```
Display    Inter (Latin) · Tajawal (Arabic)    700–900    -0.5 px tracking
Title      Inter / Tajawal                     700        -0.2 px tracking
Body       Inter / Tajawal                     500        0    px tracking
Eyebrow    Inter / Tajawal (uppercase EN)      800        +1.0 px tracking, 9–10 sp
Mono       JetBrains Mono                      500        code, payloads, tool calls

Scale (sp / px equivalent):

  display-lg   32 / 1.10   "Saqqar"
  display      24 / 1.15   chat title, sheet title
  title        18 / 1.25   section heading
  title-sm     16 / 1.3    card title
  body         15 / 1.45   message body, list rows
  body-sm      13 / 1.4    meta, captions
  label        12 / 1.3    button labels, chips
  micro        10 / 1.2    eyebrows, "PENDING APPROVAL" labels, badges
```

**Why:** The web uses 13–13.5 px as its body baseline. Phones run ~10–15 % larger physical pixels than the same number on desktop, so we step the baseline up to **15 sp** for body text. Eyebrows stay at micro size (10 sp) because uppercase 800-weight remains legible at 10 sp, and the visual rhythm depends on them feeling small.

**Tracking quirk:** Arabic does NOT respect Latin's `text-transform: uppercase` or letter-spacing — the web's CSS already disables both for `[dir="rtl"]`. The mobile design system carries the same rule.

### 2.3 — Spacing & radii

```
Spacing scale (use multiples of 4 only):
  4   6   8   10   12   14   16   20   24   32   40   56   72   96

Radii:
  pill        9999     toggle backgrounds, chips
  card-lg     22       bottom sheets, hero cards
  card        16       message bubbles, list cards
  button      12       buttons, dropdowns, inputs
  chip        8        small badges
  none        0        rare — only for screen-edge surfaces

Hit target minimum: 44 × 44 dp (Apple HIG) — never smaller, even visually.

Standard insets:
  screen-edge       16 dp
  responsive-max    980 dp (tablets — see 2.5)
  card-inner        14–18 dp
  bottom-safe       env(safe-area-inset-bottom) + 12 dp
```

### 2.4 — Motion

Three motion curves and three durations cover 95 % of cases.

```
ENTRY      easeOutCubic      180 ms     things appearing
EXIT       easeInQuad        140 ms     things leaving
SPRING     easeOutBack       320 ms     things landing decisively (FAB, splash logo)

LONG       custom             900 ms    splash zoom-in, one-time onboarding
INSTANT     —                  0 ms     respects MediaQuery.disableAnimations
```

**Specific motions:**
- **Send button → Stop button** — crossfade, 220 ms
- **Typing-row status text swap** — slide-up + fade, 220 ms (per-tool feedback)
- **Modal sheet** — DraggableScrollableSheet with 0.78 initial, 0.50 min, 0.95 max
- **Message bubble entry** — FadeSlideIn 220 ms, no stagger (independent feel)
- **Pending approvals banner** — fadeIn 180 ms, no slide (don't startle the user)
- **Splash → router** — only swap after splash's entrance has landed (zoom 0.62 → 1.0)

### 2.5 — Adaptive layout

```
phone-narrow      < 360 dp     iPhone SE — stacked controls, hide eyebrow labels
phone             360–600 dp   default target — single column
phone-wide        600–840 dp   foldables, iPad mini portrait — slightly wider gutters
tablet            > 840 dp     two-pane optional — chat list + active chat side by side
```

**Tablet behaviour:** the chat list becomes a permanent sidebar (24 % width, min 280 dp). The active chat fills the remaining space. Modals stay modals — no master/detail abuse.

---

## 3 · Information architecture

What's on the web and where it goes on mobile.

| Web surface                      | Mobile surface                                                  | Rationale                                                                                                 |
| -------------------------------- | --------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| Left sidebar (conversation list) | **Chats** tab (primary surface)                                 | The web's most important nav becomes the home tab.                                                        |
| Active chat                      | **Active chat screen** (pushed from Chats)                      | Chat is push-navigation, not embedded — gives full-bleed canvas.                                          |
| Chat header (project/env picker) | AppBar title row (taps to open env picker sheet)                | Subtle. Most users pick once and stay. Reverse the web hierarchy.                                         |
| Auto-approve, Deep think         | AppBar action icons (right side)                                | Settings that *modify the next turn* live in the AppBar. Tap = toggle, long-press = explainer.            |
| Inbox drawer (approvals)         | **Pending Approvals banner above composer** (per-chat)          | Banner is mandatory-attention. Drawer is dismissible — wrong affordance for approvals.                    |
| Inbox drawer (artifacts)         | **Inline artifact tiles in messages** + chat's "⋯ → Artifacts" | Artifacts attach to *the message that produced them*. Browsing all artifacts is a secondary action.       |
| Inbox drawer (activity)          | **Chat ⋯ → Activity timeline** (sheet)                          | Activity is a debug surface — useful but not constant. One tap away, not on the home tab.                 |
| Credential request modal         | **Bottom sheet** (keyboard-aware)                               | Modal centred is desktop pattern. Bottom sheet is mobile pattern.                                         |
| Project popup                    | **Vault tab → Project detail screen**                           | Project management is multi-screen on mobile; a popup doesn't have room.                                  |
| Environment popup                | **Project detail → Environment detail screen** (push)           | Push, not modal — feels like a hierarchical resource, not a transient form.                               |
| Profile page                     | **Account tab**                                                 | Standard mobile pattern.                                                                                  |
| Vault (footer of sidebar)        | **Vault tab** (renamed to "Projects" in the UI)                 | Vault as a footer button on web is a tell — it's not the primary verb. On mobile it's a peer tab.        |
| Theme + language toggle          | **Account → Preferences card**                                  | Consolidated. The web exposes theme in the AppBar — keep that pattern as an Account-screen sub-control. |
| Marketing landing                | **Sign-in screen brand panel**                                  | "Smart Diagnosis / Live Tools / Approval Gated / Per-User Vault" — show these on sign-in as trust signals. |

**Things that move (not direct ports):**
- "New conversation" is a button on the web sidebar. On mobile it becomes a **persistent FAB** on the Chats tab — biggest, brightest call to action.
- "Sign out" is a sidebar footer item on the web. On mobile it's at the **bottom of Account** with a destructive accent — standard pattern.
- The web has no notifications surface. Mobile **must** have one (push notifications for pending approvals when the app is closed) — added as a future P1 feature flag.

---

## 4 · Shell architecture — three options

Picking the navigation shell is the most consequential decision. Three viable options follow, scored against the five principles.

### Option A — 3-tab classic

```
 ┌───────────────────────────────────────────┐
 │              ACTIVE SURFACE               │
 │                                           │
 │                                           │
 ├───────────────────────────────────────────┤
 │   💬       📁           👤                │
 │  Chats   Projects    Account              │
 └───────────────────────────────────────────┘
```

- **Pros**: Familiar, low cognitive load, easy thumb access, scales to AR
- **Cons**: "Active chat" is pushed onto a stack — the Chats tab badge could be redundant with chat-level badges
- **Approval surfacing**: badge on Chats tab + inline banner inside each chat

**Score: ⭐⭐⭐⭐⭐ principle 1 · ⭐⭐⭐⭐⭐ principle 2 · ⭐⭐⭐⭐ principle 3 · ⭐⭐⭐⭐ principle 4**

---

### Option B — Chat-first, single stream

```
 ┌───────────────────────────────────────────┐
 │  ☰ Saqqar              ⚙   ⊕ New          │  ← always-on conversation list
 │  ───────────────────────────────────────  │
 │  📌 Pinned · prod-pulse · 2 pending       │
 │  Q4 audit · 12 messages · Yesterday       │
 │  Server logs review · …                   │
 │  …                                        │
 │                                           │
 │                                           │
 │                                           │
 │                                           │
 └───────────────────────────────────────────┘

 Drawer (left): Projects, Account, Sign out
```

- **Pros**: Maximises chat real estate, mirrors Claude/ChatGPT mobile, matches the principle "chat is the workspace"
- **Cons**: Vault and Account are one hidden layer down (drawer). Onboarding-discovery suffers. On Android, the drawer competes with system back-gesture.
- **Approval surfacing**: a status bar at the top of the conversation list ("3 pending across 2 chats") + per-row badges + per-chat banner

**Score: ⭐⭐⭐ principle 1 · ⭐⭐⭐⭐ principle 2 · ⭐⭐⭐⭐⭐ principle 3 · ⭐⭐⭐⭐ principle 4**

---

### Option C — Context-aware 5-tab with action surface

```
 ┌───────────────────────────────────────────┐
 │              ACTIVE SURFACE               │
 │                                           │
 ├───────────────────────────────────────────┤
 │  💬    📁    ⊕    🛡️    👤                │
 │ Chats  Vault New  Inbox Account           │
 │                   (3) ●                   │
 └───────────────────────────────────────────┘
```

- **Pros**: Inbox elevated to global tab — every approval is one tap away from anywhere. Centre FAB is "new conversation". Five tabs match iOS Mail / Outlook patterns.
- **Cons**: Brings back the global Inbox that we explicitly killed (per-conversation scope is load-bearing — see [feedback_per_conversation_scope.md](../../../../C:/Users/Ninja%20zone/.claude/projects/e--mostafa-Companies-Digital-Harbor-Saqqar-saqqar-app/memory/feedback_per_conversation_scope.md)). Risk of regressing past learning.
- **Approval surfacing**: dedicated tab with badge + per-chat banner unchanged

**Score: ⭐⭐⭐⭐⭐ principle 1 · ⭐⭐⭐ principle 2 (centre FAB is awkward on Android) · ⭐⭐⭐ principle 3 (chat is no longer hero)**

---

## 5 · Recommended shell

**Option A (3-tab) with smart contextual surfaces.**

```
              ┌─────────────────────────────────────────────┐
              │                                             │
              │                                             │
              │            ACTIVE SURFACE                   │
              │                                             │
              │                                             │
              │                                             │
              ├─────────────────────────────────────────────┤
              │ ┃ 3 approvals waiting on you · Tap to review│  ← global context bar (when relevant)
              ├─────────────────────────────────────────────┤
              │   💬               📁              👤        │
              │  Chats           Projects        Account     │
              │    ●(3)                                      │
              └─────────────────────────────────────────────┘
```

**Why Option A wins:**

1. **Approval surfacing solved without a dedicated tab.** The bottom tabs carry a count badge on Chats; *and* a thin global context bar surfaces above the tab bar whenever there's a cross-conversation state worth knowing (pending approvals, agent still running in another chat, offline). The bar is dismissible per-state but reappears when state changes. This gives us the discoverability of a dedicated Inbox tab without the regression risk.
2. **Three tabs is the floor for "scannable navigation".** Two tabs feels under-built. Four+ feels like a dashboard. Three matches mobile pattern strength: Instagram, Threads, X all converge on a low tab count with deep stacks.
3. **The per-conversation scope decision survives.** Inbox lives inside each chat, exactly as the user has already validated.
4. **Migration path is trivial.** The current app is already 3-tab.

The shell pattern resolves into:

```
ROOT (ShellRoute)
├── /chats                  ← Chats tab
│   ├── /                   ← Conversation list
│   ├── /new                ← New chat (active chat with empty state)
│   └── /:id                ← Active chat
│
├── /projects               ← Projects tab (was "Vault")
│   ├── /                   ← Project list
│   ├── /:projectId         ← Project detail (environments list)
│   └── /:projectId/env/:e  ← Environment detail (credentials)
│
└── /account                ← Account tab
    ├── /                   ← Profile + preferences
    ├── /password           ← Change password
    └── /about              ← Version, privacy, terms

OVERLAYS (modal / sheet)
├── Credential request sheet  (per-chat trigger)
├── Project picker sheet      (per-chat trigger)
├── Environment picker sheet  (per-chat trigger)
├── Pending approvals sheet   (per-chat ⋯ menu)
├── Artifacts sheet           (per-chat ⋯ menu)
├── Activity timeline sheet   (per-chat ⋯ menu — P1)
├── Live-env confirmation     (per-chat first send)
└── About dialog              (Account → About)
```

---

## 6 · Key screens — wireframes

ASCII at 50-char width. Each block is a phone (390 dp ≈ iPhone Pro). Annotations are inline.

### 6.1 — Splash → Sign in

```
┌──────────────────────────────────────────────┐
│                                              │
│                                              │
│                                              │
│             ●●●●●●●                          │
│           ●●         ●●                      │
│          ●     S       ●     ← brand mark
│           ●●         ●●           (gradient
│             ●●●●●●●                    plate)
│                                              │
│             Saqqar                           │
│        Odoo Operations Copilot               │
│                                              │
│                                              │
│        ▬▬▬▬▬▬▬▬▬▬                            │  ← 3 px gradient
│                                                progress bar
│                                              │
└──────────────────────────────────────────────┘
            Splash (1.4–4 s)
                 ↓
┌──────────────────────────────────────────────┐
│  ← Back                                      │
│                                              │
│       ●●●●●●●                                │
│      ●  S    ●        Saqqar                 │
│       ●●●●●●●         Operations             │
│                       Copilot                │
│                                              │
│  Sign in to continue to your workspace       │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │ Username                               │  │
│  │ ┃                                      │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │ Password                          👁    │  │
│  │ ********                               │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │             Sign in →                  │  │  ← gradient CTA
│  └────────────────────────────────────────┘  │
│                                              │
│  New to Saqqar?  Create an account →         │
│                                              │
│  ─────────────  TRUST SIGNALS  ─────────────  │  ← eyebrow
│                                              │
│   ✦ Live Odoo tools                          │
│   🛡 Approval gated on every change          │
│   🔐 Per-user encrypted vault                │
│                                              │
│        Powered by Digital Harbor             │
└──────────────────────────────────────────────┘
```

**Why this shape:**
- Logo on top, form middle, trust signals bottom. The trust signals are the four web marketing pillars — promoted to sign-in because a user installing a new "AI agent that touches my prod DB" app needs to see those guarantees before tapping Sign in.
- Single tall CTA, full-width, gradient — mirrors web.
- No social auth — saqqar.com doesn't expose any.

### 6.2 — Chats tab (home)

```
┌──────────────────────────────────────────────┐
│                                              │
│  Chats                              🔍   ⚙   │
│  3 conversations need your input             │  ← live state header
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │ 🔍 Search conversations…               │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  ▾ TODAY                                     │
│  ┌────────────────────────────────────────┐  │
│  │ ●  prod-pulse audit            2m  ··· │  │  ← pulse dot = pending
│  │    Saqqar wants to write 12 records    │  │
│  │    on res.users · acme-prod            │  │
│  │ ─────────────────────────────────────  │  │
│  │ 🟠 12 pending approval                 │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │    Q4 user export              17m     │  │
│  │    Excel ready · download              │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  ▾ YESTERDAY                                 │
│  ┌────────────────────────────────────────┐  │
│  │    Server log review                   │  │
│  │    Saqqar identified 3 errors          │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  ▾ PREVIOUS 7 DAYS                           │
│  ┌────────────────────────────────────────┐  │
│  │    Stock receipt diagnosis             │  │
│  │    Rejected by you                     │  │
│  └────────────────────────────────────────┘  │
│                                              │
│                                              │
│                              ┌──────────┐    │
│                              │  ⊕  New  │    │  ← FAB
│                              └──────────┘    │
├──────────────────────────────────────────────┤
│ ┃ 3 approvals waiting on you · Review        │  ← global context bar
├──────────────────────────────────────────────┤
│   💬  ●3        📁              👤           │
│  Chats        Projects        Account        │
└──────────────────────────────────────────────┘
```

**Design choices:**
- **Status line under the title** — "3 conversations need your input" — replaces the desktop sidebar's "Pending Approvals" header. It's the first thing the user reads.
- **Search is a tappable bar** — not an icon, not collapsed — because Saqqar users will accumulate 50+ chats fast (high-frequency tool use).
- **Date-grouped sections** — Today / Yesterday / Previous 7 / Previous 30 / Older. Matches web verbatim. Critical because chats decay quickly in relevance.
- **Pending row state** is more than a dot — it shows the *action verb*: "Saqqar wants to write 12 records on res.users." A red dot alone is dishonest; the user needs to know if it's a low-stakes read or a high-stakes write before tapping in.
- **Global context bar** above the tab bar — only renders when state exists. Tappable, opens a cross-conversation pending review sheet.
- **FAB** — gradient, anchored bottom-end (RTL-aware), single icon + label. Big enough to thumb-hit without looking.

### 6.3 — New chat (empty state)

```
┌──────────────────────────────────────────────┐
│  ← Chats                              ⚙ ✦ ⋯ │  ← back, settings, toggles
│                                              │
│  ●●● S ●●●  Saqqar          ⚪ Pick env →    │
│             Project / Environment            │
│                                              │
├──────────────────────────────────────────────┤
│  PROJECT                                     │
│  ┌───────────────────────────┐  ┌─────────┐  │
│  │ acme-prod              ▼  │  │ env  ▼  │  │
│  └───────────────────────────┘  └─────────┘  │
├──────────────────────────────────────────────┤
│                                              │
│                                              │
│           ●●●●●●●                            │
│         ●●   S   ●●                          │
│           ●●●●●●●                            │
│                                              │
│         Start a conversation                 │
│         with Saqqar                          │
│                                              │
│   Ask about live Odoo records, run           │
│   reports, or upload a document.             │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │ How many active internal users         │  │
│  │ are in prod today?                  →  │  │  ← suggestion card
│  └────────────────────────────────────────┘  │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │ Export active users to Excel.       →  │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │ Tail the Odoo log, last 100 lines.  →  │  │
│  └────────────────────────────────────────┘  │
│                                              │
├──────────────────────────────────────────────┤
│  ┌─────┐  ┌──────────────────────┐  ┌─────┐  │
│  │ 📎  │  │ Message Saqqar…      │  │  →  │  │
│  └─────┘  └──────────────────────┘  └─────┘  │
└──────────────────────────────────────────────┘
```

**Design choices:**
- **AppBar carries toggles** — ✦ = deep think, ⋯ = auto-approve (icon swaps to shieldCheck when on).
- **Header strip below AppBar** — project + env dropdowns. Two pills, each ~50 % width. No eyebrow labels in narrow mode.
- **Empty state with suggestions** — 3 tappable prompt cards drawn from the user's most-used patterns. Mirrors web exactly. Suggestions seed the composer instead of sending so the user can edit.
- **Composer pill** — attach + text field + circular gradient send. 44-dp min hit targets.

### 6.4 — Active chat (agent running)

```
┌──────────────────────────────────────────────┐
│  ← Chats           Q4 audit          ✦ ⋯  ⋮ │
│  ● gac-prod                                  │
├──────────────────────────────────────────────┤
│  PROJECT acme-prod        ENV gac-prod ▼     │
├──────────────────────────────────────────────┤
│                                              │
│   ●●  You                             10:14  │
│   ┌─────────────────────────────────────┐    │
│   │ How many users are active in prod?  │    │
│   └─────────────────────────────────────┘    │
│                                              │
│   ●●  Saqqar                          10:14  │
│   ┌─────────────────────────────────────┐    │
│   │ Let me check.                       │    │
│   └─────────────────────────────────────┘    │
│                                              │
│   ┌─────────────────────────────────────┐    │
│   │ ● ● ●  Checking Odoo data…          │    │  ← typing dots + tool status
│   └─────────────────────────────────────┘    │
│                                              │
├──────────────────────────────────────────────┤
│  ┌─────┐  ┌──────────────────────┐  ┌─────┐  │
│  │ 📎  │  │                      │  │  ■  │  │  ← Send → Stop
│  └─────┘  └──────────────────────┘  └─────┘  │
└──────────────────────────────────────────────┘
```

**Design choices:**
- **Typing row carries the tool name** — "Checking Odoo data" comes from `pendingStatusForTool()` mapped to the live tool call. As the agent moves through tools, the text crossfades up (220 ms slide-fade).
- **Send button morphs to Stop** — neutral muted styling (not warning red — see Phase 1 fix). Tap = abort the in-flight run.
- **AppBar adds ✦ deep think and ⋯ auto-approve toggles** on the right. The conversation title is still tappable to open the env picker.

### 6.5 — Pending approval (banner above composer)

```
┌──────────────────────────────────────────────┐
│  ← Chats          prod-pulse           ✦ ⋯  │
│  ● acme-prod · LIVE                          │
├──────────────────────────────────────────────┤
│  PROJECT acme-prod    ENV acme-prod ▼  LIVE │
├──────────────────────────────────────────────┤
│                                              │
│   ●●  Saqqar                          10:21  │
│   ┌─────────────────────────────────────┐    │
│   │ I need approval to write 12 records │    │
│   │ on `approval.request`.              │    │
│   └─────────────────────────────────────┘    │
│                                              │
├──────────────────────────────────────────────┤  ← banner: warning-tinted
│  ▌ PENDING APPROVAL                          │
│  ▌                                           │
│  ▌  Write approval.request  ×12   HIGH      │
│  ▌  12 records will be marked confirmed     │
│  ▌                                           │
│  ▌  [ Reject ]      [ Approve all 12 ]      │
│  ▌  Clicking "Approve all" pre-approves      │
│  ▌  future writes of this shape in this chat │
├──────────────────────────────────────────────┤
│  ┌─────┐  ┌──────────────────────┐  ┌─────┐  │
│  │ 📎  │  │ Message Saqqar…      │  │  →  │  │
│  └─────┘  └──────────────────────┘  └─────┘  │
└──────────────────────────────────────────────┘
```

**Design choices:**
- **Always above the composer, never in a menu.** Principle 1.
- **Left stripe + warning halo + uppercase eyebrow** — three independent signals that this is approval, not decoration.
- **The button text *is* the action** — "Approve all 12", not "Approve". Verb + count + scope.
- **The pre-approval tip is inline** under the button — clears up *why* "Approve all" matters and what it pre-approves. Critical for first-time exposure.
- **When multiple distinct approvals pending**, the banner shows the headline + "+2 more pending approvals →" link that opens the full sheet.

### 6.6 — Credential request (modal sheet)

```
┌──────────────────────────────────────────────┐
│                                              │
│              [chat surface dimmed]           │
│                                              │
│                                              │
├══════════════════════════════════════════════┤  ← sheet 78 % height
│            ━━━━ (drag handle)                │
│                                              │
│  🔑  SAQQAR                                  │
│  Provide access                              │
│  I need access to your Postgres DB to run    │
│  the requested SQL. Fill the fields below or │
│  reuse a saved bundle.                       │
│                                              │
│  Kind                                        │
│  ┌────────────────────────────────────────┐  │
│  │ Postgres                            ▾  │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  Host                                        │
│  ┌────────────────────────────────────────┐  │
│  │ db.acme.internal                       │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  Port                                        │
│  ┌────────────────────────────────────────┐  │
│  │ 5432                                   │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  Database / User / Password   ...            │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │ 🛡  Memorise for future chats          │  │  ← pill toggle (was checkbox)
│  └────────────────────────────────────────┘  │
│                                              │
│  ┌──────────────┐  ┌─────────────────────┐   │
│  │ Use saved →  │  │ Provide credential  │   │
│  └──────────────┘  └─────────────────────┘   │
└──────────────────────────────────────────────┘
```

**Design choices:**
- **Bottom sheet, keyboard-aware** — fields are mostly tall input → the sheet can grow to 95 %, the keyboard pushes the content up via `viewInsets.bottom`.
- **Drag handle + drag-to-dismiss** — standard Material 3 pattern.
- **Memorise as a pill toggle** — visually consistent with deep-think + auto-approve in the AppBar (Phase 1 fix).
- **Two-button row at the bottom** — primary right (Provide), secondary left (Use saved). RTL flips automatically.

### 6.7 — Projects tab

```
┌──────────────────────────────────────────────┐
│                                              │
│  Projects                              ⊕     │
│  Per-environment credentials & live status   │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │ 🔍 Search projects…                    │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │ ⬢  acme-prod                       ›  │  │
│  │    3 environments · 4 credentials     │  │
│  │ ── ── ── ── ── ── ── ── ── ── ── ──   │  │
│  │  ● prod    LIVE                       │  │
│  │  ● staging                            │  │
│  │  ● local   READ-ONLY                  │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │ ⬢  internal-tools                  ›  │  │
│  │    1 environment · 1 credential       │  │
│  │ ── ── ── ── ── ── ── ── ── ── ── ──   │  │
│  │  ● local                              │  │
│  └────────────────────────────────────────┘  │
│                                              │
│                                              │
├──────────────────────────────────────────────┤
│   💬             📁             👤           │
│  Chats        Projects        Account        │
└──────────────────────────────────────────────┘
```

**Design choices:**
- **Each project card previews its environments** — saves a tap to discover what's inside. Status dots + LIVE/READ-ONLY badges visible at a glance.
- **Tap card → push to project detail.** Tap env row → push to env detail.
- **⊕ in the AppBar** = new project. Sheet (not push) because project creation is a single-field form.

### 6.8 — Project detail → Environment detail

```
Project detail                          Environment detail
┌─────────────────────────────────┐     ┌─────────────────────────────────┐
│ ← Projects     acme-prod   ⋯   │     │ ← acme-prod    prod         ⋯   │
│                                 │     │  LIVE · 3 credentials           │
├─────────────────────────────────┤     ├─────────────────────────────────┤
│ ⬢  acme-prod                    │     │                                 │
│    Created Apr 2026             │     │  CREDENTIALS                    │
│                                 │     │  ┌───────────────────────────┐  │
│  ── ENVIRONMENTS  ⊕             │     │  │ 🗃  Postgres              │  │
│                                 │     │  │    db.acme.internal       │  │
│  ┌───────────────────────────┐  │     │  │    Verified 2 hours ago   │  │
│  │ ● prod              LIVE  │  │     │  │    💾 Memorised      ⋯    │  │
│  │   3 credentials       ›   │  │     │  └───────────────────────────┘  │
│  └───────────────────────────┘  │     │                                 │
│  ┌───────────────────────────┐  │     │  ┌───────────────────────────┐  │
│  │ ● staging                 │  │     │  │ 🧬  XML-RPC               │  │
│  │   2 credentials       ›   │  │     │  │    odoo.acme.internal     │  │
│  └───────────────────────────┘  │     │  │    Verified yesterday     │  │
│  ┌───────────────────────────┐  │     │  └───────────────────────────┘  │
│  │ ● local       READ-ONLY   │  │     │                                 │
│  │   1 credential        ›   │  │     │  ⊕ Add credential               │
│  └───────────────────────────┘  │     │                                 │
│                                 │     │  ☐ Read-only                    │
│                                 │     │  ☑ Live                         │
│                                 │     │  ☐ Auto-approve writes          │
└─────────────────────────────────┘     └─────────────────────────────────┘
```

**Design choices:**
- **Cred row shows lifecycle state** — verified timestamp + memorised badge. Trust signals where they live.
- **Env flags as a footer card** — Live / Read-only / Auto-approve. Toggling Live triggers a confirmation ("Marking env as LIVE turns on the chat warning gate. Continue?").
- **Add credential opens a bottom sheet** with the same schema-driven form used inline in chat — single source.

### 6.9 — Account tab

```
┌──────────────────────────────────────────────┐
│                                              │
│  Account                                     │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │           ●●●●●                        │  │
│  │          ●  T  ●                       │  │
│  │           ●●●●●                        │  │
│  │                                        │  │
│  │           test                         │  │
│  │      ai-tools@digital-harbor.net       │  │
│  │                                        │  │
│  │   3 projects · 47 conversations         │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  PREFERENCES                                 │
│  ┌────────────────────────────────────────┐  │
│  │ 🎨 Theme                  Dark      ›  │  │
│  ├────────────────────────────────────────┤  │
│  │ 🌐 Language               English   ›  │  │
│  ├────────────────────────────────────────┤  │
│  │ ✦  Deep think (default)   On         ◉ │  │
│  ├────────────────────────────────────────┤  │
│  │ 🔔 Notifications          Approvals ›  │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  SECURITY                                    │
│  ┌────────────────────────────────────────┐  │
│  │ 🔑 Change password                  ›  │  │
│  ├────────────────────────────────────────┤  │
│  │ 🛡 App lock (biometric)         Off ◯ │  │  ← P1
│  └────────────────────────────────────────┘  │
│                                              │
│  ABOUT                                       │
│  ┌────────────────────────────────────────┐  │
│  │ ℹ️ Version                  1.0.0+1    │  │
│  ├────────────────────────────────────────┤  │
│  │ 📄 Privacy policy                   ↗  │  │
│  ├────────────────────────────────────────┤  │
│  │ 📜 Terms of service                 ↗  │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │              Sign out                  │  │  ← destructive ghost
│  └────────────────────────────────────────┘  │
└──────────────────────────────────────────────┘
```

**Design choices:**
- **Hero profile card** — avatar + name + email + workspace counts. The counts ("3 projects · 47 conversations") are a tiny piece of life-stats that makes the surface feel alive.
- **Sections separated by uppercase eyebrows** — Preferences / Security / About — matches the web's information hierarchy.
- **App lock + notifications as future P1 toggles** — visible but disabled with "Soon" chip until shipped.
- **Sign out at the bottom** — destructive accent, full-width ghost button, easy to find but not accidentally tappable.

### 6.10 — Onboarding (first launch, post sign-in)

```
3-card swipeable tour, dismissable from any frame, never shown again.

┌────────────────────┐  ┌────────────────────┐  ┌────────────────────┐
│  ●●● S ●●●         │  │  ●●● S ●●●         │  │  ●●● S ●●●         │
│                    │  │                    │  │                    │
│  Chat is the       │  │  Approvals are     │  │  Vault is yours,   │
│  workspace         │  │  always one tap    │  │  and only yours    │
│                    │  │                    │  │                    │
│  Ask Saqqar to     │  │  Risky actions     │  │  Credentials are   │
│  inspect Odoo,     │  │  pause for your    │  │  encrypted per     │
│  query the DB, or  │  │  approval — never  │  │  user. Saqqar uses │
│  generate Excel.   │  │  silently applied. │  │  them only when    │
│                    │  │                    │  │  needed.           │
│                    │  │                    │  │                    │
│  ●  ○  ○           │  │  ○  ●  ○           │  │  ○  ○  ●           │
│        Skip   →    │  │        Skip   →    │  │        Start →     │
└────────────────────┘  └────────────────────┘  └────────────────────┘
```

**Design choices:**
- **Three frames, one minute.** Each frame teaches ONE thing. Card 1 sets expectation ("this is how to use it"). Card 2 builds trust ("you stay in control"). Card 3 builds trust again ("your credentials are private").
- **Skip is always visible.** Power users will skip. Don't punish them.

---

## 7 · Interaction patterns

### 7.1 — Gestures (universal)

| Gesture                   | Action                                      | Where                                                              |
| ------------------------- | ------------------------------------------- | ------------------------------------------------------------------ |
| Tap                       | Primary action                              | Everywhere                                                         |
| Long-press                | Reveal context menu / explainer             | Conversation rows, message bubbles, toggle icons (tooltip)         |
| Swipe-right on conv row   | Archive (with undo toast)                   | Chats list                                                         |
| Swipe-left on conv row    | Delete (with confirmation dialog)           | Chats list                                                         |
| Pull-to-refresh           | Sync conversation / credential list        | Chats list, Projects list, Environment detail                      |
| Swipe-down on sheet       | Dismiss the sheet                           | All bottom sheets                                                  |
| Pinch on artifact image   | Zoom                                        | Image artifacts in messages                                        |
| Long-press on message     | Copy / share / quote                        | Message bubbles                                                    |

### 7.2 — Navigation transitions

| From → To                       | Transition                                       |
| ------------------------------- | ------------------------------------------------ |
| Splash → Sign in                | Cross-fade 280 ms                                |
| Sign in → Home                  | Slide-up 320 ms, easeOutCubic                    |
| Tab switch                      | Fade 180 ms (no slide — tab order is irrelevant) |
| Chats list → Active chat        | Push slide (platform-default — iOS slide, Android shared-axis) |
| Active chat → Project picker    | Modal sheet rise 280 ms easeOutCubic              |
| Project detail → Env detail     | Push slide (same as above)                       |
| Any → Sign out                  | Confirmation dialog → cross-fade to Sign in 280 ms |

### 7.3 — Live state surfacing

The agent is asynchronous. The user starts a turn, may switch tabs, may close the app. Live state surfaces in 5 places:

1. **Chat-level typing row** — agent reasoning / tool calls (Phase 1)
2. **Conversation row pulse dot** — pending state in the list
3. **Bottom-tab badge** — count of conversations with pending approvals
4. **Global context bar** — cross-conversation summary above tab bar
5. **Push notification** — when app is closed and an approval is requested (P1)

---

## 8 · Edge cases

The cases that look easy on the happy path and ugly when neglected.

### 8.1 — Offline

```
┌──────────────────────────────────────────────┐
│  ⚠  You're offline. Saqqar can't run tools.  │  ← persistent banner
├──────────────────────────────────────────────┤
│                                              │
│  [chat content remains scrollable, readable] │
│                                              │
├──────────────────────────────────────────────┤
│  ┌─────┐  ┌──────────────────────┐  ┌─────┐  │
│  │ 📎  │  │ Message Saqqar…      │  │ ⊘  │  │  ← disabled send
│  └─────┘  └──────────────────────┘  └─────┘  │
└──────────────────────────────────────────────┘
```

- Pending writes are NOT queued — the agent can't know what credential state the server has.
- The banner is persistent until connectivity returns.
- All "Approve" buttons are disabled with a tooltip "Connect to approve."

### 8.2 — Long-running tool (Excel generation 30s+)

```
   ●●  Saqqar                          10:42
   ┌─────────────────────────────────────┐
   │ ⠋ ⠙ ⠹  Building Excel report…       │
   │ This usually takes 20–40 seconds.   │  ← progressive disclosure
   │                                     │
   │ [ Stop ]                            │
   └─────────────────────────────────────┘
```

- After 8 s with no progress signal, the typing row adds a "this usually takes..." hint.
- Stop button appears inline in the typing row (in addition to the composer's Send→Stop swap).

### 8.3 — Empty states

Every list has a custom empty state — never just a blank.

```
NO CONVERSATIONS                      NO PROJECTS
┌─────────────────────┐               ┌─────────────────────┐
│                     │               │                     │
│      ●●●●●          │               │       ●●●           │
│                     │               │                     │
│   Start your first  │               │  No projects yet    │
│      conversation   │               │                     │
│                     │               │  Add a project to   │
│  Ask Saqqar about   │               │  let Saqqar work    │
│  Odoo, your DB, or  │               │  against your Odoo  │
│  generate a report. │               │  deployments.       │
│                     │               │                     │
│  [+ Start chatting] │               │  [+ Add project]    │
│                     │               │                     │
└─────────────────────┘               └─────────────────────┘
```

### 8.4 — Errors (agent failure, API timeout)

```
   ●●  Saqqar                          10:45
   ┌─────────────────────────────────────┐
   │ ⚠  Something went wrong while       │  ← error tinted (danger soft)
   │   reading the Odoo log. The server  │
   │   returned 502. Retry?              │
   │                                     │
   │ [ Show details ]   [ Retry ]        │
   └─────────────────────────────────────┘
```

- Error bubble is visually distinct (danger-tinted left stripe).
- "Show details" expands to the technical payload (status code, error message, request id) — engineers need this.
- "Retry" re-runs the failed turn.

### 8.5 — RTL mirroring

- All `Padding`, `Border`, `Alignment` use directional variants (`EdgeInsetsDirectional`, `BorderRadiusDirectional`, `AlignmentDirectional`).
- Send button stays bottom-end (right in LTR, left in RTL).
- Chat bubbles: user on the end, assistant on the start. Mirrors correctly.
- Toggle icons (chevron, arrow) flip horizontally via `Transform.flip` when in RTL.
- Eyebrow labels lose uppercase + tracking in Arabic (CSS-equivalent: `[dir="rtl"] .eyebrow { text-transform: none; letter-spacing: 0; }`).

---

## 9 · Accessibility checklist

| Concern                       | Requirement                                                                                                         |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| Contrast                      | Text against bg: 4.5:1 minimum (WCAG AA). Brand cyan on dark navy: 7.2:1 ✓                                          |
| Dynamic type                  | All text scales with system setting, clamped to [0.85, 1.4] to protect fixed-height surfaces (composer pill, FAB)   |
| Reduce motion                 | All entry / exit animations check `MediaQuery.disableAnimationsOf(context)` and short-circuit to instant            |
| Hit targets                   | 44 × 44 dp minimum, even when visual element is smaller (icon buttons use padding)                                  |
| Screen-reader labels          | Every IconButton has `tooltip` (used as semantic label). Toggles announce "Auto-approve, on" / "Auto-approve, off"  |
| Focus order                   | Reading order, never visual order. Verified per screen.                                                              |
| Live regions                  | Typing row + pending approval banner marked as `LiveRegion(politeness: polite)` so screen readers announce updates  |
| RTL                           | Tested via `Directionality(textDirection: TextDirection.rtl, …)` in widget tests                                    |

---

## 10 · Implementation phases

How to ship without overcommitting.

### Phase 0 — Foundation (already built — current app)

Splash, sign in, 3-tab shell, chat screen scaffold, vault scaffold, account, i18n (EN+AR), theme switcher, demo data layer, approval gating per chat. **Done.**

### Phase 1 — Web parity (in progress)

Deep think toggle, Stop generating, Memorise credential toggle, Tool-aware typing status, Approve-all-N labelling, Coming-soon badges, AppBar layout shift, ModalBottomSheet for credentials. **Done as of this commit.**

### Phase 2 — Pre-production

| Feature                                | Why                                              | Estimate |
| -------------------------------------- | ------------------------------------------------ | -------- |
| Backend integration (token auth, real API) | Replace demo data                                | 1 week   |
| Streaming responses (SSE / polling)    | Match web's live update model                    | 3 days   |
| Crash reporting (Sentry)               | Pre-prod requirement                             | 1 day    |
| Analytics events catalog (Mixpanel)    | Funnel + retention measurement                   | 2 days   |
| CI/CD (GitHub Actions)                 | Build + test + ship pipelines                    | 2 days   |

### Phase 3 — Native moments

| Feature                                | Why                                              | Estimate |
| -------------------------------------- | ------------------------------------------------ | -------- |
| Push notifications (FCM)               | Wake user for pending approvals                  | 3 days   |
| Biometric / PIN app lock               | Vault holds credentials — phone-loss protection  | 2 days   |
| First-run onboarding tour              | Trust-build + discoverability                    | 2 days   |
| Activity timeline tab in ⋯ menu        | Web parity (last unmissing surface)              | 2 days   |
| Multi-account / "Switch workspace"     | Enterprise users with multiple Saqqar tenants    | 4 days   |

### Phase 4 — Polish

| Feature                                | Estimate |
| -------------------------------------- | -------- |
| Pull-to-refresh on all lists           | 1 day    |
| Swipe gestures on conversation rows    | 1 day    |
| Project recent-pills above dropdown    | 1 day    |
| Dark/Light system-default theme        | 0.5 day  |
| Live env warning sound (haptic)        | 0.5 day  |
| Improved skeleton loaders              | 1 day    |
| Animated tab badge counts              | 0.5 day  |

---

## 11 · Open questions for the client

The decisions I'd want signed off before building.

1. **Multi-tenant?** Does a single user ever switch between Saqqar workspaces? If yes, Phase 3 multi-account becomes a Phase 2 must-have.
2. **Notification policy?** What pings the user via push? Approvals only? Excel ready? Agent error?
3. **Offline read-mode?** Should past conversations be readable offline? (Implies local DB.)
4. **App lock granularity?** Lock the whole app, or just the Vault tab?
5. **Audio?** Do we want a "talk to Saqqar" voice input for hands-free use during incidents?
6. **Tablet?** Is iPad / Android tablet a near-term target? If yes, two-pane layouts get budget.
7. **Brand evolution?** Is the cyan/purple gradient permanent, or is it scheduled for a refresh? (If the latter, isolate it behind tokens.)

---

## 12 · The one-page summary

If a stakeholder reads only one section, this is it.

**Saqqar Mobile is a chat-first companion to saqqaar.com**, designed around a single insight: **the user opens the app to give approval or ask a question, then leaves.** Sessions are short, intent-driven, and high-stakes (live Odoo, prod databases).

**Shell**: 3 tabs — Chats / Projects / Account. The Chats tab is the home. Active chat is pushed onto its stack with full-screen treatment.

**Brand**: Dark-first navy + cyan/purple gradient, Inter + Tajawal type, dramatic shadows on key surfaces. Lifted from the web's design tokens — the two products are visually one product.

**Critical pattern**: pending approvals **never** hide behind a menu. They surface as a warning-tinted banner above the composer in every chat that has them, plus a count badge on the Chats tab, plus a global context bar above the tab bar when state spans multiple chats. Three layers of redundancy because **approval is sacred** (principle 1).

**Differentiator from generic chat apps** (Claude, ChatGPT mobile): Saqqar has a Vault. The Vault is a peer tab, not a settings sub-screen, because credentials are first-class data — viewable, addable, deletable, memorised on approval. Each credential row shows its lifecycle state (verified-at, memorised vs. session-only) so the user trusts the chain of custody at a glance.

**Mobile-native moments** that the web doesn't have:
- Push notifications for pending approvals (the most valuable native feature for this product)
- Biometric / PIN app lock for the Vault
- Pull-to-refresh on lists
- Swipe gestures on conversation rows
- Bottom sheets instead of centred modals
- Streaming responses with progressive tool-call disclosure

The result is an app that feels like a real Saqqar surface — not a mobile-wrapper of the website — while staying tight enough to ship in two months from a clean slate.

---

*Drafted 2026-05-16 — see [pubspec.yaml](../pubspec.yaml) for the actual current version, and [feedback_per_conversation_scope.md](../../../../C:/Users/Ninja%20zone/.claude/projects/e--mostafa-Companies-Digital-Harbor-Saqqar-saqqar-app/memory/feedback_per_conversation_scope.md) for the load-bearing constraint that pinned this design.*
