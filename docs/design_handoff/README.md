# Saqqar — Design Handoff (for claude.ai/design)

Upload these to a **new** claude.ai/design project (the old "Saqqar Design System"
project no longer exists). Order: paste `SAQQAR_DESIGN_BRIEF.md` first, then attach the
screenshots from `screens/` and the logos.

## Files
- **SAQQAR_DESIGN_BRIEF.md** — full product + design-tokens brief. Paste as the first message.
- **screens/** — real screenshots from the running app (Android, dark theme), captured 2026-06-25.

## Screens captured
| File | Screen |
|---|---|
| `01_auth.png` | Sign in — **light theme** |
| `02_auth_dark.png` | Sign in — **dark theme** (ambient gradient visible) |
| `03_auth_password.png` | Password login screen |
| `05_chats.png` | Chats tab — conversation list (date groups, search, FAB) |
| `06_chat.png` | Conversation — agent reply with "Saqqar thinking", RTL Arabic, inline code, numbered list |
| `07_projects.png` | Projects tab — project list (the middle nav tab) |
| `08_account.png` | Account — profile card, usage stats, Plan & usage (Max 20x), personal info |
| `09_pricing.png` | Plans & pricing — Free / Pro $20 / Max $100 with feature lists |
| `10_project_environments.png` | Project sheet — environments (Auto-approve / Open / Delete / Live / Read-only) |

## Notes for the designer (reality vs. brief)
- Bottom nav is **Chats / Projects / Account** (there is no standalone "Vault" tab).
- Credentials ("Vault") surface from the **Account** stats and inside projects/environments.
- All screenshots are **dark theme**; light theme exists (see `01_auth.png`) but needs polish.
- Brand logos to attach: `assets/img/saqqar-logo-dark.png`, `assets/img/saqqar-logo-light.png`.
