// Turns the JSON export into one SVG per screen, for the drag-and-drop route.
//
//   node design/build_svg.js
//
// Why this exists alongside the plugin: Figma imports SVG natively, and it
// imports it as *editable nodes* — rectangles stay rectangles, `<text>` stays
// live text. So a designer with nothing but a browser can drag a file onto a
// canvas and start editing, with no plugin to install, no desktop app, and no
// developer-mode dialog. It gives up the parts of the plugin that have no SVG
// equivalent — variables, shared styles, the screenshot underlay — which is
// exactly the trade a first look wants to make.
//
// Text is the whole difficulty. SVG `<text>` does not wrap: a two-line label
// written as one string runs off the side of the frame. The export records
// where each line actually broke, measured by the same shaper that drew the
// screen, and each becomes its own `<tspan>` at its own measured position.

const fs = require('fs');
const path = require('path');

const EXPORT_DIR = path.join(__dirname, 'export');
const OUT_DIR = path.join(EXPORT_DIR, 'svg');

// ── Entry ────────────────────────────────────────────────────────────────

function main() {
  if (!fs.existsSync(EXPORT_DIR)) {
    console.error('No design/export — run: flutter test test/figma_export_test.dart');
    process.exit(1);
  }
  fs.mkdirSync(OUT_DIR, { recursive: true });

  const index = readJson(path.join(EXPORT_DIR, 'index.json'));
  const screens = [];

  for (const entry of index.screens) {
    const screen = readJson(path.join(EXPORT_DIR, entry.file));
    screens.push(screen);
    const file = entry.file.replace(/\.json$/, '.svg');
    fs.writeFileSync(path.join(OUT_DIR, file), render(screen));
    console.log(`  ${screen.name} → svg/${file}`);
  }

  const all = path.join(OUT_DIR, ALL_FILE);
  fs.writeFileSync(all, renderAll(screens));

  console.log(`\n${screens.length} SVG files in design/export/svg/`);
  console.log(`Plus svg/${ALL_FILE} — every screen in one file.`);
  console.log('Drag onto a Figma canvas; each imports as editable layers.');
}

/// The whole app on one board.
///
/// One drag instead of nine, which is the difference between "try this" and a
/// chore. Each screen is its own `<g>` with a title, so Figma imports them as
/// named groups laid out left to right rather than one undifferentiated pile.
const ALL_FILE = 'saqqar-all-screens.svg';
const BOARD_GAP = 80;
const LABEL_BAND = 44;

function renderAll(screens) {
  const height = Math.max.apply(null, screens.map((s) => s.height));
  const width = screens.reduce((sum, s) => sum + s.width + BOARD_GAP, BOARD_GAP);

  const defs = [];
  const groups = [];
  let x = BOARD_GAP;

  for (const screen of screens) {
    const body = screen.layers
      .map((layer) => renderLayer(layer, defs))
      .filter(Boolean);

    groups.push(
      `<g transform="translate(${x}, ${LABEL_BAND})" ` +
        `data-name="${escapeAttr(screen.name)}">`,
      `<text x="0" y="-14" font-family="Space Grotesk" font-size="15" ` +
        `font-weight="700" fill="#0F172A" ` +
        `data-name="${escapeAttr(screen.name)} label">` +
        `${escapeText(screen.name)}</text>`,
      `<rect width="${screen.width}" height="${screen.height}" fill="#FFFFFF" ` +
        `stroke="#E2E8F0" data-name="Frame"/>`,
      body.join('\n'),
      '</g>'
    );

    x += screen.width + BOARD_GAP;
  }

  const total = height + LABEL_BAND + BOARD_GAP;
  return [
    `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" ` +
      `height="${total}" viewBox="0 0 ${width} ${total}">`,
    '<title>Saqqar — all screens</title>',
    defs.length ? `<defs>\n${defs.join('\n')}\n</defs>` : '',
    `<rect width="${width}" height="${total}" fill="#F8FAFC"/>`,
    groups.join('\n'),
    '</svg>',
  ].filter(Boolean).join('\n');
}

function readJson(file) {
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

// ── Document ─────────────────────────────────────────────────────────────

function render(screen) {
  const defs = [];
  const body = [];

  for (const layer of screen.layers) {
    const markup = renderLayer(layer, defs);
    if (markup) body.push(markup);
  }

  return [
    `<svg xmlns="http://www.w3.org/2000/svg" width="${screen.width}" ` +
      `height="${screen.height}" viewBox="0 0 ${screen.width} ${screen.height}">`,
    `<title>${escapeText(screen.name)}</title>`,
    defs.length ? `<defs>\n${defs.join('\n')}\n</defs>` : '',
    // A named background rect so the imported frame has a floor to sit on;
    // without it Figma imports a group with a transparent bounding box and
    // the screen reads as a pile of floating parts.
    `<rect width="${screen.width}" height="${screen.height}" fill="#FFFFFF"/>`,
    body.join('\n'),
    '</svg>',
  ].filter(Boolean).join('\n');
}

let uid = 0;
function nextId(prefix) {
  uid += 1;
  return `${prefix}${uid}`;
}

// ── Layers ───────────────────────────────────────────────────────────────

function renderLayer(layer, defs) {
  if (layer.type === 'text') return renderText(layer);
  if (layer.type === 'rect') return renderRect(layer, defs);
  if (layer.type === 'image') return renderImagePlaceholder(layer);
  // `custom` markers are deliberately dropped: a dashed box is useful as an
  // annotation in a review page, but it would import into Figma as a real
  // layer someone has to find and delete.
  return null;
}

function renderRect(layer, defs) {
  const attrs = [
    `x="${layer.x}"`,
    `y="${layer.y}"`,
    `width="${Math.max(layer.w, 0.01)}"`,
    `height="${Math.max(layer.h, 0.01)}"`,
  ];

  const radii = cornerRadii(layer);
  // SVG has one `rx` for all four corners. Where the export asked for four
  // different ones, the largest is the honest approximation — a bottom-sheet
  // top-rounded panel imports fully rounded rather than square.
  const radius = Math.max.apply(null, radii);
  if (radius > 0) attrs.push(`rx="${radius}"`);

  if (layer.gradient) {
    const id = nextId('grad');
    defs.push(gradientDef(id, layer.gradient));
    attrs.push(`fill="url(#${id})"`);
  } else if (layer.fill) {
    const { color, opacity } = splitColor(layer.fill);
    attrs.push(`fill="${color}"`);
    if (opacity < 1) attrs.push(`fill-opacity="${round(opacity)}"`);
  } else {
    attrs.push('fill="none"');
  }

  const stroke = layer.stroke;
  if (stroke) {
    const { color, opacity } = splitColor(stroke.color);
    attrs.push(`stroke="${color}"`);
    if (opacity < 1) attrs.push(`stroke-opacity="${round(opacity)}"`);
    // Per-side strokes have no SVG equivalent on a rect. The widest side is
    // used so a single-sided rule still reads as a line rather than vanishing.
    const width = typeof stroke.width === 'number'
      ? stroke.width
      : Math.max(stroke.top || 0, stroke.right || 0,
                 stroke.bottom || 0, stroke.left || 0);
    attrs.push(`stroke-width="${width}"`);
  }

  if (layer.shadows && layer.shadows.length) {
    const id = nextId('shadow');
    defs.push(shadowDef(id, layer.shadows));
    attrs.push(`filter="url(#${id})"`);
  }

  if (typeof layer.opacity === 'number') {
    attrs.push(`opacity="${round(layer.opacity)}"`);
  }

  attrs.push(`data-name="${escapeAttr(layer.name)}"`);
  return `<rect ${attrs.join(' ')}/>`;
}

/// Images export as their bounding box, tinted if the app tinted them.
///
/// The bytes are not inlined: the export writes a full-resolution screenshot
/// of the whole screen already, and embedding a second copy of every logo
/// would bloat a file whose point is to be dragged around.
function renderImagePlaceholder(layer) {
  const fill = layer.tint ? splitColor(layer.tint).color : '#CBD5E1';
  const radius = Math.max.apply(null, cornerRadii(layer));
  return `<rect x="${layer.x}" y="${layer.y}" width="${Math.max(layer.w, 0.01)}" ` +
    `height="${Math.max(layer.h, 0.01)}"${radius > 0 ? ` rx="${radius}"` : ''} ` +
    `fill="${fill}" fill-opacity="0.25" ` +
    `data-name="${escapeAttr(layer.name)} (image)"/>`;
}

// ── Text ─────────────────────────────────────────────────────────────────

const FONT_NAMES = {
  SpaceGrotesk: 'Space Grotesk',
  IBMPlexSansArabic: 'IBM Plex Sans Arabic',
  JetBrainsMono: 'JetBrains Mono',
  Lucide: 'Lucide',
};

/// Flutter's internal family name → the name a font picker shows.
///
/// A font that lives in a package is registered as
/// `packages/<package>/<family>`, and that whole string arrives in the export
/// because it is genuinely what the `TextStyle` carried. Written into an SVG
/// verbatim it is a family nothing will ever match, so the package prefix is
/// stripped before the table lookup.
function fontFamily(name) {
  if (!name) return 'Inter';
  const bare = String(name).split('/').pop();
  return FONT_NAMES[bare] || bare;
}

/// True for a glyph from an icon font.
///
/// Icon sets map their glyphs into the Unicode Private Use Area, so a
/// single-character run up there is an icon and not text. Worth detecting
/// because the fix is different: text needs the right font installed, an icon
/// needs replacing with a real vector.
function isIconGlyph(text) {
  if (!text) return false;
  const chars = Array.from(text);
  if (chars.length !== 1) return false;
  const code = chars[0].codePointAt(0);
  return code >= 0xE000 && code <= 0xF8FF;
}

function renderText(layer) {
  const font = layer.font || {};
  const size = Math.max(font.size || 14, 1);
  const family = fontFamily(font.family);
  const { color, opacity } = splitColor(font.color || '#000000FF');

  const attrs = [
    `font-family="${escapeAttr(family)}"`,
    `font-size="${size}"`,
    `font-weight="${font.weight || 400}"`,
    `fill="${color}"`,
  ];
  if (opacity < 1) attrs.push(`fill-opacity="${round(opacity)}"`);
  if (font.letterSpacing) attrs.push(`letter-spacing="${font.letterSpacing}"`);
  if (font.italic) attrs.push('font-style="italic"');
  if (font.underline) attrs.push('text-decoration="underline"');
  if (layer.dir === 'rtl') attrs.push('direction="rtl"');
  if (typeof layer.opacity === 'number') {
    attrs.push(`opacity="${round(layer.opacity)}"`);
  }

  // Named so the layers panel says what the empty box is. Lucide is not a
  // Google font, so unlike the three text faces it will usually be missing —
  // and "Icon U+E019 (Lucide)" tells a designer to drop a real vector in,
  // where "RichText" would just look like a bug.
  if (isIconGlyph(layer.text)) {
    const code = Array.from(layer.text)[0].codePointAt(0)
      .toString(16).toUpperCase();
    attrs.push(`data-name="Icon U+${code} (${family})"`);
  } else {
    attrs.push(`data-name="${escapeAttr(layer.name)}"`);
  }

  const anchor = textAnchor(layer);
  if (anchor) attrs.push(`text-anchor="${anchor}"`);

  const lines = Array.isArray(layer.lines) && layer.lines.length
    ? layer.lines
    : null;

  if (!lines) {
    // No measured lines (empty, or past the walk cap). Place the whole string
    // on one baseline derived from the box — still correctly positioned, just
    // not wrapped.
    const y = layer.y + baselineOffset(size, font.lineHeight);
    return `<text x="${anchorX(layer, anchor)}" y="${round(y)}" ` +
      `${attrs.join(' ')}>${escapeText(layer.text || '')}</text>`;
  }

  const spans = lines.map((line) => {
    // `line.top` is the top of that line's box; the baseline sits one ascent
    // below it. 0.78 em is close enough across the app's three faces that the
    // difference is under a pixel at label sizes.
    const y = layer.y + line.top + baselineOffset(size, font.lineHeight);
    const x = anchor
      ? anchorX(layer, anchor)
      : round(layer.x + (line.x || 0));
    return `<tspan x="${x}" y="${round(y)}">${escapeText(line.text)}</tspan>`;
  });

  return `<text ${attrs.join(' ')}>${spans.join('')}</text>`;
}

/// Distance from the top of a line box down to its alphabetic baseline.
function baselineOffset(size, lineHeight) {
  const ascent = size * 0.78;
  if (!lineHeight || lineHeight <= size) return ascent;
  // With an explicit line height the glyphs sit centred in the taller box.
  return (lineHeight - size) / 2 + ascent;
}

function textAnchor(layer) {
  const rtl = layer.dir === 'rtl';
  if (layer.align === 'center') return 'middle';
  if (layer.align === 'right') return 'end';
  if (layer.align === 'end') return rtl ? 'start' : 'end';
  if (layer.align === 'start') return rtl ? 'end' : null;
  return null;
}

function anchorX(layer, anchor) {
  if (anchor === 'middle') return round(layer.x + layer.w / 2);
  if (anchor === 'end') return round(layer.x + layer.w);
  return round(layer.x);
}

// ── Paint ────────────────────────────────────────────────────────────────

function cornerRadii(layer) {
  const r = layer.radius;
  if (r === 'circle') return [Math.min(layer.w, layer.h) / 2];
  if (Array.isArray(r)) return r;
  return [typeof r === 'number' ? r : 0];
}

/// `#RRGGBBAA` → SVG's separate colour and opacity.
function splitColor(hex) {
  const raw = String(hex || '#000000FF').replace('#', '');
  const rgb = '#' + raw.slice(0, 6);
  const alpha = raw.length >= 8 ? parseInt(raw.slice(6, 8), 16) / 255 : 1;
  return { color: rgb, opacity: isNaN(alpha) ? 1 : alpha };
}

function gradientDef(id, gradient) {
  const from = gradient.from || [0, 0];
  const to = gradient.to || [1, 1];
  const stops = (gradient.colors || []).map((hex, i) => {
    const { color, opacity } = splitColor(hex);
    const position = Array.isArray(gradient.stops) &&
      typeof gradient.stops[i] === 'number'
        ? gradient.stops[i]
        : (gradient.colors.length > 1 ? i / (gradient.colors.length - 1) : 0);
    return `<stop offset="${round(position)}" stop-color="${color}"` +
      (opacity < 1 ? ` stop-opacity="${round(opacity)}"` : '') + '/>';
  });

  // objectBoundingBox units are the same 0–1 space the export records the
  // handles in, so the coordinates go straight through.
  return `<linearGradient id="${id}" x1="${from[0]}" y1="${from[1]}" ` +
    `x2="${to[0]}" y2="${to[1]}">${stops.join('')}</linearGradient>`;
}

function shadowDef(id, shadows) {
  const drops = shadows.filter((s) => !s.inner).map((s) => {
    const { color, opacity } = splitColor(s.color);
    // SVG blurs by standard deviation; a CSS/Flutter blur radius is roughly
    // twice that, which is the same relationship Figma uses.
    return `<feDropShadow dx="${s.dx || 0}" dy="${s.dy || 0}" ` +
      `stdDeviation="${round((s.blur || 0) / 2)}" flood-color="${color}" ` +
      `flood-opacity="${round(opacity)}"/>`;
  });

  // Room for the blur to spread; the default -10%/120% region clips a soft
  // 30 px shadow on a short row into a visible rectangle.
  return `<filter id="${id}" x="-50%" y="-50%" width="200%" height="200%">` +
    `${drops.join('')}</filter>`;
}

// ── Escaping ─────────────────────────────────────────────────────────────

function escapeText(value) {
  return String(value == null ? '' : value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
}

function escapeAttr(value) {
  return escapeText(value).replace(/"/g, '&quot;');
}

function round(value) {
  return Math.round(Number(value) * 100) / 100;
}

main();
