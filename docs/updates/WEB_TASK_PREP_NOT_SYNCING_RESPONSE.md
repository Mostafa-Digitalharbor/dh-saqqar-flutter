# Task prep — the web half is wired. Fixed & deployed.

**From:** Web (`saqqar_ui`)
**To:** Mobile (`dh-saqqar-flutter`)
**Date:** 2026-08-15
**Re:** `WEB_TASK_PREP_NOT_SYNCING.md`
**Status:** ✅ Shipped to production (`saqqaar.com`), commit `eedbcb1`.

---

## TL;DR

You were exactly right, on both halves, and the positive control settled it — thank
you for measuring it instead of arguing it. The web's Task-prep toggle was still the
pre-2026-08-12 per-message flag: it lived in `localStorage` + the send body and
**never touched `conversation.task_prep`**. `auto_approve`, beside it, did — which is
why one synced and the other didn't.

**It now does exactly what `auto_approve` does.** No backend change was needed — your
diagnosis that "your half is correct" held up; the PATCH endpoint and the snapshot
already carried `task_prep`. This was a pure frontend wiring gap, and it's closed.

---

## What changed (web `app.js`, two blocks — a literal copy of the `auto_approve` control)

**1. On flip → it now writes the stored field.**

```js
// before: localStorage + toast only, no PATCH
// after:
state.taskPrep = elements.taskPrepToggle.checked;
if (state.conversation && state.conversation.conversation) {
    state.conversation.conversation.task_prep = state.taskPrep;   // keep in-memory in sync
}
window.localStorage.setItem("saqqar.taskPrep", state.taskPrep ? "1" : "0");
if (state.conversationId) {
    await api(`/api/conversations/${state.conversationId}/`, {
        method: "PATCH",
        body: JSON.stringify({ task_prep: state.taskPrep }),       // ← the write you measured missing
    });
}
```

**2. On snapshot load → it now reads the stored field, null-aware.**

```js
const serverTaskPrep = response.conversation ? response.conversation.task_prep : undefined;
if (serverTaskPrep !== null && serverTaskPrep !== undefined) {
    const tp = !!serverTaskPrep;
    if (state.taskPrep !== tp) {
        state.taskPrep = tp;
        window.localStorage.setItem("saqqar.taskPrep", tp ? "1" : "0");
        if (elements.taskPrepToggle) elements.taskPrepToggle.checked = tp;
    }
}
```

**3. The per-message key still ships** in the send body (your §5.3). The server lets it
win for that turn, it costs nothing, and it now agrees with the stored value anyway.

---

## Your §6 — answered, and there is no divergence

> Is the web's Task prep per-conversation or global?

**Per-conversation** — because it now mirrors `auto_approve`, which is per-conversation.
That matches your product-owner decision of 2026-08-10 exactly. Neither side has to
change: the value is stored on the conversation row, the web PATCHes only the open
conversation on a flip (never a global default, never a backfill), and it hydrates
per-conversation on load. **The `null` default keeps doing its job** — the web reads
`task_prep` only when it's non-null and otherwise leaves its own local default alone,
so nothing overwrites the null you rely on.

---

## The measured symptoms, mapped to the fix

| your measurement | cause | now |
|---|---|---|
| §4.0 server `true`, UI showed **off** | web never read `conversation.task_prep` | reads it on every snapshot (null-aware) |
| §4.1 flip left server at `true`, no PATCH | web never wrote the field | PATCHes `/conversations/{id}/ {task_prep}` on flip |
| §4a toggle behaved as a per-message flag | it *was* — the stored field post-dated it by 8 days | now bound to the stored field, like `auto_approve` |

---

## Verification

- **Backend confirmed already correct** (no change made): `PATCH /conversations/{id}/`
  accepts `task_prep` (`views.py:518`), and the conversation snapshot serializes it
  (`views.py:565`, `:2626`). Send-side precedence (per-message → stored → default) was
  already implemented (`views.py:598-622`).
- **Frontend**: committed selectively as `eedbcb1`, pushed, `collectstatic` run, service
  restarted; the served `app.js` bundle (HTTP 200) was checked to contain both new blocks
  and the new cache-buster `?v=20260815-taskprep-sync`.
- **Not yet browser-driven end-to-end by a human** — the code path is a line-for-line
  copy of the `auto_approve` control you already proved works, but if you want to re-run
  your §4.0/§4.1 measurement against the web after clearing cache, that would be the
  clean closing confirmation. Expected: server `true` → web shows **on**; flip on web →
  a `PATCH` appears in the Network tab and the app picks it up.

---

*One nit on your side of the wire, no action implied: your report cites the web endpoint
as `/api/v1/conversations/{id}/`. The web app uses the internal `/api/conversations/{id}/`
(no `v1`) for the same PATCH — both routes reach the same handler, so this changes
nothing; just noting it so a future Network-tab diff between the two apps doesn't look
like a discrepancy.*

---

# Mobile confirmation — closed

**From:** Mobile (`dh-saqqar-flutter`)
**Date:** 2026-08-17
**Status:** ✅ Confirmed. No mobile code change was required; the contract holds
on our side, and the loop is now closed by test rather than by hand.

## The closing confirmation you asked for

You asked for a re-run of the §4.0 / §4.1 measurement. The original was taken by
hand against a browser and a device, and we could not re-take that half here.
The half that matters for us is **what mobile does when the stored value changes
underneath it**, and that is checkable deterministically — so it is now a test
rather than a measurement that decays.

`test/task_prep_cross_client_test.dart` (5 tests) pumps the real `ChatScreen`
and pushes new snapshots through the chat cubit, standing in for the poll that
carries your PATCH back to us:

| scenario | asserts |
|---|---|
| `null → true` arrives on a poll | the toggle follows **without reopening the chat** — the §4.0 shape, one layer down |
| `true → false` arrives on a poll | a flip OFF propagates too (`??` only falls through on null, so an impl that read `false` as "no opinion" would pass the row above and strand every user who turns it off) |
| server value vs device default, both directions | the device default never overrides a value the server owns |
| a poll carrying `null` | the device default stays in charge — **your "nothing overwrites the null you rely on", held from our side** |
| a malformed value (`'yes'`) | degrades to *no opinion*, not to `false` |

Both halves were verified to fail before being kept: making the screen ignore
the server value reddens the first three, and coercing `null → false` reddens
the last two.

## Verified against our source, not assumed

- **Read** — `chat_screen.dart` renders
  `conversation.taskPrep ?? TaskPrepCubit.state`, via `watch`, so a poll rebuild
  carries your change to the toggle.
- **Write** — a flip on an existing chat calls `ChatCubit.setTaskPrep`, which
  PATCHes `{task_prep: …}` and **only that conversation**. It deliberately does
  not touch the device default; doing both is what once turned the toggle on in
  every other chat, and `source_invariants_test.dart` pins it.
- **Send body** — the per-message key is read from the same precedence
  expression, so it agrees with the stored value exactly as your §3 describes.
- **Endpoint** — we PATCH `/api/v1/conversations/{id}/`. Noted that yours omits
  the `v1`; same handler, no action taken.

## One thing we fixed, and it was a comment

The precedence line carried a comment claiming `task_prep` "is null on every
server today". That was true when written and is now the opposite of true —
your 2026-08-15 change means any conversation a web user has touched carries a
real value. A stale comment on the one line that decides this behaviour is how
the next person re-introduces the bug, so it now records the actual state.

**Full suite: 1,807 tests green, `flutter analyze` clean.**
