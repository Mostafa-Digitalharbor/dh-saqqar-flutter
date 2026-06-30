# App Store screenshots

Ready-to-upload screenshots for App Store Connect.

## Target sizes (what App Store Connect accepts)
- **iPhone 6.5" slot**: `1284 x 2778` portrait (the 6.5" slot also accepts
  1242×2688; it does NOT accept 1290×2796 — that's the 6.9"/6.7" size).
- **iPad 13"**: `2732 x 2048` landscape

## How to generate
1. Drop your original screenshots into **`_source/`** (any filenames).
   - **Portrait** images → treated as **iPhone**.
   - **Landscape** images → treated as **iPad**.
2. Run:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\convert.ps1
   ```
3. Upload the results:
   - `iphone_6.5/` → the iPhone 6.5" screenshot slot.
   - `ipad_13/`    → the iPad 13" screenshot slot.

## What the script does
- iPhone: scales **cover** + centre-crops to exactly 1290×2796 (full-bleed, no bars).
- iPad: scales **contain** onto a dark canvas to exactly 2732×2048 (no content lost; thin dark bars top/bottom because the source 16:10 is wider than iPad's 4:3).
- Flattens to 24-bit RGB PNG (no alpha — App Store rejects transparency).

Files are numbered (`01_…`, `02_…`) by source filename order, so name your
sources `1_login.png`, `2_chats.png`, … to control the on-store order.
