# Saqqar → Figma

Rebuilds the app's screens and design tokens as native, editable Figma nodes.

There is no off-the-shelf tool for this direction. Every Figma/Flutter plugin on
the market goes design → code; nothing goes code → design.

**There is also no way to produce a shareable Figma link from outside Figma.**
The REST API is read-only for nodes — it has no endpoint that creates a layer,
at any permission level. The only write path into a Figma document is a plugin
running inside the editor under the account that owns the file, or an import
the user performs. So the file has to originate on the designer's machine; the
two routes below are the shortest versions of that, and once the file exists
its own Share button produces the link.

## How it works

```
flutter test test/figma_export_test.dart     →  design/export/*.json
                                                        ↓
                                    Figma → Plugins → Development → Import
                                                        ↓
                                             design/figma_plugin/  → frames
```

Three generators write the bundle, all under `test/support/`:

| File | Produces | Reads from |
|---|---|---|
| `figma_tokens.dart` | `tokens.json` | `AppTheme.light()` / `AppTheme.dark()` |
| `figma_exporter.dart` | one JSON per screen | the pumped **render** tree |
| `figma_fonts.dart` | one PNG per screen | a `RepaintBoundary`, rasterised |

and `design/build_svg.js` turns the JSON into `design/export/svg/*.svg`.

The screen exporter is the part that makes this 1:1 rather than approximate. It
walks `RenderObject`s, not widgets: a widget says `Padding(all: 16)`, a
RenderObject says "this box is at (16, 216) and is 398 × 72". Every coordinate
in the export survived the real constraint solve, at the real text scale, with
the real font metrics — so the frame Figma draws is the layout the device draws,
not a re-derivation of it.

The screenshots are the other half, and they answer a different question. The
layer walk can only carry what a `RenderObject` *declares*; anything painted
imperatively — a `CustomPainter`, a backdrop blur, a shader — exists in the
raster and nowhere else. Each screen therefore imports as its real bitmap,
locked, with the editable layers stacked on top of it. Hide the bitmap once the
rebuild is trusted; keep it while you are checking.

They are captured inside the Flutter engine through a `RepaintBoundary`, not
from the OS. That is not a shortcut — the app sets `FLAG_SECURE`, so Android's
own `screencap` returns a black frame. Going through the engine also means the
export needs no emulator, no signed-in account and no network, and reproduces
byte-for-byte on any machine.

`tokens.json` is generated from the built themes rather than from `AppColors`
directly, because the *theme* is what decides `bg` means `lightBg` on one side
and `darkBg` on the other. That pairing is what lets one Figma variable carry
both modes: the app's Light/Dark themes become the two columns in Figma's
variables table, and a component bound to `surface/bg` flips with the page.

## Two ways in

**Drag and drop SVG** — no plugin, no desktop app, works in Figma on the web.
Figma imports SVG as *editable nodes*: a rect stays a rect, `<text>` stays live
text.

```bash
node design/build_svg.js      # writes design/export/svg/
```

Drag `svg/saqqar-all-screens.svg` onto a canvas — every screen, each as a named
group, in one file. Individual screens are in the same folder if you only want
one.

What SVG cannot carry, and the plugin can: variables, shared styles, the
screenshot underlay, per-side borders (they widen to a full box) and
per-corner radii (they collapse to the largest). For a first look, or for
handing one screen to someone, this is the faster road.

**The plugin** — everything, at the cost of Figma desktop and a one-time
import.

## Running the plugin

**1. Export.**

```bash
flutter test test/figma_export_test.dart
```

Writes `design/export/` — `tokens.json`, `index.json`, one JSON per screen, and
`png/` with the rasters.

**2. Import.** In the Figma **desktop** app (the browser cannot load a local
plugin), open any file, then:

*Menu → Plugins → Development → Import plugin from manifest…* and choose
`design/figma_plugin/manifest.json`.

**3. Run.** *Plugins → Development → Saqqar Design Import*, point it at the
whole `design/export` folder — the folder, so `png/` comes with it — press
Import.

You get one frame per screen laid out left to right, each with its screenshot
locked underneath the editable layers, plus variable collections (Saqqar Color
with Light/Dark modes, Radius, Spacing), text styles, effect styles and
gradient styles. Re-running places the new set beside the old one rather than
on top of it.

Two checkboxes change what gets built: **underlay** (on by default) drops the
locked screenshot in behind the layers, and **screenshots only** skips the
layer rebuild entirely for when you just want the pictures.

## Fonts

Two separate font problems, and they are not the same problem.

**In Figma**, install **Space Grotesk**, **IBM Plex Sans Arabic** and
**JetBrains Mono** — all three are on Google Fonts — before importing. The
plugin substitutes Inter for anything missing and says so in its log, but
substituted type will not measure the same as the app, and the export's fixed
text boxes will clip or gap accordingly.

**In the export**, `figma_fonts.dart` registers those same faces plus the icon
fonts into the test engine. `flutter test` ships with no fonts at all — every
family resolves to Ahem, whose glyphs are solid black boxes — so without it the
screenshots come out as a wall of black rectangles. Icon fonts that live in a
package (Lucide, Cupertino) must register under their *qualified* name,
`packages/<package>/<family>`; registering the bare family loads the file
successfully and then silently matches no glyph, which renders every icon as an
empty square with nothing in the log.

Because this is the only harness in the repo that measures with the shipping
fonts, it is also the only one that can see a `Row` that fits in Ahem and
overflows in Space Grotesk. It reports any it finds, per screen.

## What is exact, and what is not

Exact: every position and size, fills, gradients, borders (including
single-sided ones), corner radii, shadows, opacity, text content, font size,
weight, letter spacing, line height, and text alignment.

Not exact **in the layers** — all of it is correct in the screenshot
underneath, which is why the screenshot is there:

- **Backdrop blur.** The glass surfaces use `ImageFilter.blur(sigma)`; Figma's
  background blur takes a radius. There is no exact conversion — the values
  need an eye, not a formula.
- **Arabic line breaking.** Figma's text engine breaks Arabic differently from
  Flutter's, so an RTL export's boxes are right but its wraps can differ.
- **Gradient interpolation.** Skia and Figma blend stops in slightly different
  spaces. Endpoints match; the middle can drift a shade.
- **Icons.** Icon fonts render as text in the export. They land as the right
  glyph in the right box only if the icon font is installed; otherwise they are
  a correctly-placed empty box to swap for a vector.
- **Anything drawn in a `CustomPainter`.** The waveform bars and the ambient
  background glow are canvas ops with no declarative shape to read, so the layer
  walk records only their position and size, marked with a dashed outline. They
  are the two places to draw by hand.

## Structure

The exported layers are flat and in paint order — index 0 is furthest back, the
same as Figma's own child order. That is deliberate. The render tree's grouping
is layout scaffolding (`RenderFlex`, `RenderPadding`) with no pixels of its own,
and rebuilding a hierarchy out of it would invent structure the design never
had. Group and componentise from the flat frames instead: they are correct, and
correctness is the part a human cannot redo quickly.
