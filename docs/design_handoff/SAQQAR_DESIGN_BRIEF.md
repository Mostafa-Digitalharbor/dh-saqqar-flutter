# Saqqar — Design System Brief

> Paste this whole document into a new claude.ai/design project as the first message.
> Goal: have Claude understand the product, then iteratively design a **complete,
> production-ready design system** for it, discussing variants with me until I approve.
> The approved tokens/components will be ported back into the Flutter app.

---

## 1. What Saqqar is

Saqqar is the **mobile app (Flutter, Android + iOS)** companion to the web product at
**saqqaar.com** — an Odoo-based **AI agent** that talks to users in natural language and
performs real actions on their business systems (an "agent that does things", not just a
chatbot). The mobile app is where a user:

- chats with the AI agent in real time,
- reviews and **approves/rejects actions** the agent wants to take (per-conversation),
- inspects **artifacts** the agent produced (files, transcripts, outputs),
- manages **credentials / connected systems** ("Vault"),
- manages their **account, plan, and billing**.

**Primary language: Arabic (RTL).** English is secondary. Every layout must be
**RTL-first** and mirror correctly. Bilingual labels are common.

**Audience:** business users (SMB owners, ops staff) in the MENA region. Tone should feel
**trustworthy, modern, calm, and "in control"** — this is an agent acting on the user's
behalf, so the UI must communicate safety, transparency, and reversibility, never "magic
black box."

---

## 2. Information architecture (current)

Bottom navigation = **3 tabs only** (verified in the running app):

1. **Chats** — list of conversations → conversation (chat) screen.
2. **Projects** — list of projects; each project opens a sheet of **environments**
   (per-env: Auto-approve toggle, Open, Delete, Live / Read-only).
3. **Account** — profile, stats (conversations / credentials / approvals / artifacts),
   current plan + "See plans", personal info.

**Credentials ("Vault")** are not a top-level tab — they surface from the Account stats
("N credentials") and within projects/environments. The "Add credential" form is
schema-driven (fields come from a backend schema), so its UI must be generic/dynamic.

**Load-bearing rule:** approvals, artifacts, and actions are **per-conversation**. They
live INSIDE each chat (via a ⋯ overflow menu on the conversation), NOT as global tabs.
Do not propose global "Approvals" or "Artifacts" tabs.

### Screens to design
- Auth: multi-step email-OTP flow (sign in / sign up, OTP entry).
- Conversations list (Chats tab).
- Chat / conversation screen (the core screen — message stream).
- Per-conversation ⋯ menu → Approvals, Artifacts, Actions panels.
- Vault: credentials list + "Add credential" (schema-driven forms — fields come from a
  backend schema, so the form UI must be generic/dynamic, not hardcoded per provider).
- Account screen + "Current Plan" card (shows plan name, usage/limits).
- Billing / Pricing screen (plan tiers).
- Shared transcript (read-only public view of a conversation).

---

## 3. Brand & visual language

- **Aesthetic:** dark-first, "glass" surfaces (translucent cards over an ambient
  gradient background), subtle depth, cyan→navy as the primary energy, cyan→purple as the
  vivid accent. Think "calm control room," not neon gaming.
- **Ambient background:** soft blurred color blobs ("saqqar-ambient") behind glass
  surfaces. Keep it subtle so text stays readable.
- Must ship **both dark and light themes** (light theme exists but needs polish).

---

## 4. Design tokens (current source of truth — from the Flutter theme)

These are the EXACT current values. Treat them as the starting palette to refine, not as
locked. When you propose changes, keep semantic names (`--surface`, `--border`, `--text`,
`--accent`, etc.) so they map cleanly back to Flutter.

### 4.1 Colors — Dark theme
| Token | Hex / RGBA |
|---|---|
| bg | `#030712` |
| surface | `#111827` |
| surface2 | `#1E293B` |
| surface3 | `#0F172A` |
| text | `#F8FAFC` |
| muted | `#94A3B8` |
| border | `#1E293B` |
| cardBg | `rgba(17,24,39,0.70)` |
| cardBorder | `rgba(30,41,59,0.80)` |
| hoverBg | `rgba(30,41,59,0.08)` |

### 4.2 Colors — Light theme
| Token | Hex / RGBA |
|---|---|
| bg | `#F8FAFC` |
| surface | `#FFFFFF` |
| surface2 | `#F1F5F9` |
| surface3 | `#E2E8F0` |
| text | `#0F172A` |
| muted | `#64748B` |
| border | `#E2E8F0` |
| cardBg | `rgba(255,255,255,0.85)` |
| cardBorder | `rgba(226,232,240,0.95)` |
| hoverBg | `rgba(226,232,240,0.08)` |

### 4.3 Brand & status (theme-agnostic)
| Token | Hex |
|---|---|
| brandCyan | `#06B6D4` |
| brandCyanStrong | `#22D3EE` |
| brandPurple | `#8B5CF6` |
| brandNavy | `#1F3C88` |
| success | `#10B981` |
| warning | `#F59E0B` |
| danger | `#EF4444` |
| overlay (dark) | `rgba(2,6,23,0.72)` |
| cyan pop shadow | `0 10px 30px rgba(6,182,212,0.18)` |

### 4.4 Gradients
- **Primary CTA** (buttons/FABs): `navy #1F3C88 → cyan #06B6D4`, top-left → bottom-right.
- **Vivid accent** (avatars, gradient text only — never large fills): `cyan → purple`.
- **User chat bubble:** `rgba(cyan,0.12) → rgba(purple,0.08)`.
- **Server-activity bubble:** `rgba(purple,0.06) → rgba(cyan,0.04)`.
- **Active conversation row:** `rgba(cyan,0.10) → rgba(purple,0.10)`.

### 4.5 Typography
Type scale (in pt). App currently uses **platform default fonts** (Android: Roboto + Noto
Sans Arabic; iOS: SF + SF Arabic) — but I'm open to a stronger type identity (e.g.
**Tajawal** for Arabic + **Inter** for Latin) if you make the case visually.

| Role | Size | Weight |
|---|---|---|
| Display L/M | 28 | 700 |
| Display S | 24 | 700 |
| Headline L | 22 | 700 |
| Headline M | 20 | 700 |
| Headline S | 18 | 700 |
| Title L | 16 | 600 |
| Title M | 15 | 600 |
| Title S | 14 | 600 |
| Body L | 16 / line-height 1.5 | 400 |
| Body M | 14 / 1.5 | 400 |
| Body S | 13 / 1.45 | 400 (muted) |
| Label L | 14 | 600 |
| Label M | 12 | 600 (muted) |
| Label S | 11 | 700 (muted) |
| Eyebrow (caps) | 11, uppercase, +0.10em | 700 |
| Status pill | 10, uppercase, +0.10em | 700 |
| Mono (code) | 12 / 1.45 | monospace |

### 4.6 Radius
card 20 · button 12 · pill 999 · input 14 · toast 12 · modal 18 · sheetTop 24 ·
bubble 16 · row 12

### 4.7 Spacing scale
xs 4 · sm 8 · md 12 · lg 16 · xl 20 · xxl 24 · xxxl 32

### 4.8 Motion (durations, ms)
cardIn 220 · menuIn 150 · toastIn 250 · listFadeIn 400 · pulseDot 2000 · scanLine 2600 ·
cursorBlink 900 · thinkingDots 1000 · themeTransition 300

---

## 5. Components I need in the system

Buttons (primary gradient / secondary / ghost / icon), input fields, OTP input, glass
cards, conversation row, chat bubbles (user / agent / server-activity / thinking state),
status pills, approval card (approve/reject), artifact card, credential row, dynamic form
field, plan card, pricing tier card, bottom sheet, modal, toast/snackbar, empty states,
loading/skeleton states, ambient background.

---

## 6. What I want you (Claude) to do

1. **First, read this brief and reflect it back** — show me you understand the product,
   the RTL constraint, and the per-conversation rule. Ask me anything unclear.
2. Build a **token layer** (CSS variables) for dark + light from §4, refining where weak
   (light theme especially needs work; glass depth and chat hierarchy can be stronger).
3. Build the **components** in §5 as HTML/JSX preview cards, `dir="rtl" lang="ar"`, using
   only **semantic CSS variables** (never raw hex inline).
4. Assemble **full-screen mockups** for the screens in §2.
5. For anything you improve, show a **before / after** so I can compare.
6. Iterate with me until I approve a version. Keep everything mappable back to Flutter
   tokens (semantic names matching §4) so I can port it.

**Constraints:** RTL-first; dark + light; Arabic + English; mobile viewport (~390×844);
calm/trustworthy tone; keep it portable to Flutter (no web-only effects that can't be
reproduced in Flutter — e.g. heavy CSS filters are fine for mockups but flag them).

---

## 7. Hand-off back to Flutter (FYI — so you keep it portable)
Final approved values get ported into `lib/core/theme/` (app_colors, app_typography,
app_gradients, app_radius, saqqar_theme_extension). So: semantic token names, real hex
values, and note any effect that's hard to do natively in Flutter.
