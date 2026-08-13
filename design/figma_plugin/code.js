// Saqqar Design Import — rebuilds the app's screens and design tokens as
// native Figma nodes from the JSON that `test/figma_export_test.dart` writes.
//
// Plain JavaScript on purpose: no TypeScript, no bundler, no `npm install`.
// Figma runs `main` as-is, so the whole plugin is three files you point the
// "Import plugin from manifest…" dialog at. A build step would be one more
// thing to keep working on a machine that only ever needs to run this when
// the design changes.
//
// What it builds, in order:
//   1. Variable collections — Color (Light + Dark modes), Radius, Spacing
//   2. Text styles, effect styles, gradient paint styles
//   3. One frame per exported screen, laid out left to right
//
// Coordinates arrive already absolute and already in paint order, so a screen
// is a flat append loop rather than a tree rebuild. That is deliberate: the
// export reads Flutter's *render* tree, where a Row that positions three chips
// has no pixels of its own, and reconstructing a widget hierarchy out of it
// would invent grouping the design never had.

const FRAME_GAP = 80;

// ── Entry point ──────────────────────────────────────────────────────────

figma.showUI(__html__, { width: 420, height: 460, themeColors: true });

figma.ui.onmessage = async (msg) => {
  if (msg.type !== 'import') return;

  try {
    const summary = { variables: 0, styles: 0, screens: 0, layers: 0 };
    const options = {
      underlay: msg.underlay !== false,
      screenshotsOnly: msg.screenshotsOnly === true,
    };

    if (msg.tokens && !options.screenshotsOnly) {
      const counts = await buildTokens(msg.tokens);
      summary.variables = counts.variables;
      summary.styles = counts.styles;
    }

    const screens = msg.screens || [];
    let cursorX = nextFreeX();

    for (let i = 0; i < screens.length; i++) {
      const screen = screens[i];
      post('progress', `Building ${screen.name}… (${i + 1}/${screens.length})`);

      const frame = await buildScreen(screen, cursorX, options);
      cursorX += frame.width + FRAME_GAP;
      summary.screens += 1;
      if (!options.screenshotsOnly) {
        summary.layers += (screen.layers || []).length;
      }

      // Hand the event loop back between screens. Without it a nine-screen
      // import is one long synchronous block and Figma paints nothing until
      // it finishes, which reads as a hang rather than as progress.
      await pause();
    }

    if (summary.screens > 0) {
      figma.viewport.scrollAndZoomIntoView(figma.currentPage.children);
    }

    post('done', summary);
  } catch (error) {
    post('error', String((error && error.stack) || error));
  }
};

function post(type, payload) {
  figma.ui.postMessage({ type: type, payload: payload });
}

function pause() {
  return new Promise((resolve) => setTimeout(resolve, 0));
}

/// Starts the import to the right of whatever is already on the page, so a
/// second run sits beside the first instead of on top of it.
function nextFreeX() {
  const nodes = figma.currentPage.children;
  if (nodes.length === 0) return 0;
  let right = -Infinity;
  for (const node of nodes) {
    if (typeof node.x === 'number' && typeof node.width === 'number') {
      right = Math.max(right, node.x + node.width);
    }
  }
  return right === -Infinity ? 0 : right + FRAME_GAP * 2;
}

// ── Tokens ───────────────────────────────────────────────────────────────

async function buildTokens(tokens) {
  let variables = 0;
  let styles = 0;

  post('progress', 'Creating variables…');

  // Colour is the only collection with two modes, and the mapping is exact:
  // the app's Light/Dark themes are the same two columns Figma shows in the
  // variables table, so a component bound to `surface/bg` flips with the page
  // the same way the app flips with the OS setting.
  const colorCollection = createCollection('Saqqar Color');
  if (colorCollection) {
    const lightMode = colorCollection.modes[0].modeId;
    colorCollection.renameMode(lightMode, 'Light');

    // A second mode is a paid-plan feature — Figma Free allows exactly one.
    // Losing the dark column costs the theme switch, not the palette, so the
    // import continues with light values only rather than failing outright.
    let darkMode = null;
    try {
      darkMode = colorCollection.addMode('Dark');
    } catch (error) {
      post('warn', 'This Figma plan allows one variable mode, so only the ' +
        'light palette was imported. Dark values are in tokens.json.');
    }

    for (const token of tokens.colors || []) {
      const variable = createVariable(token.name, colorCollection, 'COLOR');
      if (!variable) continue;
      variable.setValueForMode(lightMode, rgba(token.light));
      if (darkMode) variable.setValueForMode(darkMode, rgba(token.dark));
      variables += 1;
    }
  }

  variables += buildNumberCollection('Saqqar Radius', tokens.radius);
  variables += buildNumberCollection('Saqqar Spacing', tokens.spacing);

  post('progress', 'Creating text styles…');
  for (const token of tokens.text || []) {
    const font = await resolveFont(token.family, token.weight);
    const style = figma.createTextStyle();
    style.name = token.name;
    style.fontName = font;
    style.fontSize = Math.max(token.size || 14, 1);
    style.letterSpacing = { value: token.letterSpacing || 0, unit: 'PIXELS' };
    style.lineHeight = token.lineHeight
      ? { value: token.lineHeight, unit: 'PIXELS' }
      : { unit: 'AUTO' };
    styles += 1;
  }

  post('progress', 'Creating effect + gradient styles…');
  for (const token of tokens.effects || []) {
    const style = figma.createEffectStyle();
    style.name = token.name;
    style.effects = (token.shadows || []).map(dropShadow);
    styles += 1;
  }

  for (const token of tokens.gradients || []) {
    const style = figma.createPaintStyle();
    style.name = token.name;
    style.paints = [linearGradient(token)];
    styles += 1;
  }

  return { variables: variables, styles: styles };
}

function buildNumberCollection(name, tokens) {
  if (!tokens || tokens.length === 0) return 0;
  const collection = createCollection(name);
  if (!collection) return 0;

  const mode = collection.modes[0].modeId;
  collection.renameMode(mode, 'Value');

  let count = 0;
  for (const token of tokens) {
    const variable = createVariable(token.name, collection, 'FLOAT');
    if (!variable) continue;
    variable.setValueForMode(mode, token.value);
    count += 1;
  }
  return count;
}

function createCollection(name) {
  try {
    return figma.variables.createVariableCollection(name);
  } catch (error) {
    // Variables are a paid-plan feature. Losing them is survivable — the
    // screens still import, and they carry raw colours rather than bound
    // ones — so this warns instead of aborting the run.
    post('warn', 'Could not create variable collection "' + name + '". ' +
      'Variables need a paid Figma plan; screens will still import.');
    return null;
  }
}

/// `createVariable` changed signature across API versions — it took a
/// collection *id* before it took the collection object. Both are tried so the
/// plugin works on whichever the user's Figma ships.
function createVariable(name, collection, type) {
  try {
    return figma.variables.createVariable(name, collection, type);
  } catch (error) {
    try {
      return figma.variables.createVariable(name, collection.id, type);
    } catch (inner) {
      return null;
    }
  }
}

// ── Screens ──────────────────────────────────────────────────────────────

async function buildScreen(screen, x, options) {
  const frame = figma.createFrame();
  frame.name = screen.name;
  frame.x = x;
  frame.y = 0;
  frame.resize(Math.max(screen.width, 1), Math.max(screen.height, 1));
  // The export already dropped everything outside the viewport, but a text
  // run whose Figma font is wider than its Flutter one can still spill a few
  // pixels. Clipping keeps the frame reading as a device screen.
  frame.clipsContent = true;
  frame.fills = [];

  const images = await decodeImages(screen.images || {});

  if (options.underlay && screen.screenshotBytes) {
    addUnderlay(frame, screen);
  }

  // Screenshot-only mode: the raster is the whole point, so skip the layer
  // rebuild entirely rather than stacking editable copies on top of it.
  if (options.screenshotsOnly && screen.screenshotBytes) return frame;

  for (const layer of screen.layers || []) {
    const node = await buildLayer(layer, images);
    if (!node) continue;

    // Parent first, position second — and never the other way round. A node
    // created at the page root carries page coordinates, and `appendChild`
    // preserves its *absolute* position by rewriting x/y relative to the new
    // parent. Setting them beforehand means every layer in the second frame
    // onwards gets shifted left by that frame's own x.
    frame.appendChild(node);
    node.x = layer.x;
    node.y = layer.y;
  }

  return frame;
}

/// The real screenshot, laid in behind everything else.
///
/// This is the ground truth: Flutter's own raster of the screen, captured
/// through a `RepaintBoundary` inside the test engine — not an OS screenshot,
/// which the app's `FLAG_SECURE` would return black. Two things live only
/// here and in no reconstructed layer: work done by a `CustomPainter`, and
/// backdrop blur. Keeping it under the editable stack means the layers always
/// have something exact to be checked against.
///
/// Locked, because the one thing nobody wants is to nudge the reference while
/// dragging a layer on top of it. Unlock it from the layers panel, or hide it
/// with the eye once the rebuild is trusted.
function addUnderlay(frame, screen) {
  let hash;
  try {
    hash = figma.createImage(new Uint8Array(screen.screenshotBytes)).hash;
  } catch (error) {
    post('warn', 'Screenshot for ' + screen.name + ' could not be decoded.');
    return;
  }

  const node = figma.createRectangle();
  node.name = '📷 Screenshot — reference (locked)';
  node.resize(Math.max(screen.width, 1), Math.max(screen.height, 1));
  // FILL, not FIT: the PNG is captured at 2× and has exactly the frame's
  // aspect ratio, so filling scales it back to logical pixels with no crop.
  node.fills = [{ type: 'IMAGE', imageHash: hash, scaleMode: 'FILL' }];
  frame.appendChild(node);
  node.x = 0;
  node.y = 0;
  node.locked = true;
}

/// `figma.createImage` is synchronous but decoding is not free, so images are
/// hashed once per screen and reused across every layer that shows them.
async function decodeImages(images) {
  const hashes = {};
  for (const id of Object.keys(images)) {
    try {
      hashes[id] = figma.createImage(new Uint8Array(images[id])).hash;
    } catch (error) {
      // A malformed PNG should cost one logo, not the whole import.
    }
  }
  return hashes;
}

async function buildLayer(layer, images) {
  if (layer.type === 'text') return buildText(layer);
  if (layer.type === 'image') return buildImage(layer, images);
  if (layer.type === 'rect') return buildRect(layer);
  if (layer.type === 'custom') return buildPlaceholder(layer);
  return null;
}

/// A `CustomPainter`'s footprint — the waveform bars, the ambient glow.
///
/// Drawn as a dashed magenta outline rather than skipped: these are the two or
/// three things in the app that genuinely cannot be exported, and a designer
/// needs to see exactly where they sit and how big they are. An empty gap in
/// an otherwise-exact frame reads as an export bug; a labelled box reads as
/// the instruction it is.
function buildPlaceholder(layer) {
  const node = figma.createRectangle();
  place(node, layer);
  node.name = '✎ ' + (layer.painter || 'CustomPaint') + ' — draw by hand';
  node.fills = [];
  node.strokes = [{
    type: 'SOLID',
    color: { r: 1, g: 0.2, b: 0.6 },
    opacity: 0.9,
  }];
  node.strokeWeight = 1;
  node.dashPattern = [4, 3];
  return node;
}

/// Name, size and opacity only. Position is applied by the caller *after*
/// `appendChild` — see the note in `buildScreen`.
function place(node, layer) {
  node.name = layer.name || 'Layer';
  // `resize` rejects anything below 0.01, and a hairline can round to zero.
  node.resize(Math.max(layer.w, 0.01), Math.max(layer.h, 0.01));
  if (typeof layer.opacity === 'number') node.opacity = layer.opacity;
}

// ── Rectangles ───────────────────────────────────────────────────────────

function buildRect(layer) {
  const node = figma.createRectangle();
  place(node, layer);

  const fills = [];
  if (layer.gradient) {
    const paint = gradientPaint(layer.gradient);
    if (paint) fills.push(paint);
  } else if (layer.fill) {
    fills.push(solid(layer.fill));
  }
  node.fills = fills;

  applyRadius(node, layer);
  applyStroke(node, layer.stroke);

  if (layer.shadows && layer.shadows.length > 0) {
    node.effects = layer.shadows.map(dropShadow);
  }

  return node;
}

function applyRadius(node, layer) {
  const radius = layer.radius;
  if (radius === 'circle') {
    node.cornerRadius = Math.min(layer.w, layer.h) / 2;
    return;
  }
  if (!Array.isArray(radius)) {
    node.cornerRadius = typeof radius === 'number' ? radius : 0;
    return;
  }
  node.topLeftRadius = radius[0];
  node.topRightRadius = radius[1];
  node.bottomRightRadius = radius[2];
  node.bottomLeftRadius = radius[3];
}

/// Flutter paints a `BoxDecoration` border inside the box, so `INSIDE` is the
/// alignment that keeps a bordered card the same total size in both tools —
/// Figma's default (`CENTER`) would make every card a pixel wider than the app
/// draws it, and those pixels compound through a stack of nested surfaces.
function applyStroke(node, stroke) {
  if (!stroke) return;
  node.strokes = [solid(stroke.color)];
  node.strokeAlign = 'INSIDE';

  if (typeof stroke.width === 'number') {
    node.strokeWeight = Math.max(stroke.width, 0.01);
    return;
  }

  // Per-side weights: a single-sided hairline (a section rule, the composer's
  // top border) that a uniform stroke would turn into a full box.
  try {
    node.strokeTopWeight = stroke.top || 0;
    node.strokeRightWeight = stroke.right || 0;
    node.strokeBottomWeight = stroke.bottom || 0;
    node.strokeLeftWeight = stroke.left || 0;
  } catch (error) {
    node.strokeWeight = Math.max(
      stroke.top || stroke.bottom || stroke.left || stroke.right || 1,
      0.01
    );
  }
}

// ── Text ─────────────────────────────────────────────────────────────────

const ALIGN = {
  left: 'LEFT',
  right: 'RIGHT',
  center: 'CENTER',
  justify: 'JUSTIFIED',
};

async function buildText(layer) {
  const font = layer.font || {};
  const resolved = await resolveFont(font.family, font.weight);

  const node = figma.createText();
  // Order matters: Figma rejects `characters` until the node has a font it
  // has already loaded.
  node.fontName = resolved;
  node.characters = layer.text || '';
  node.fontSize = Math.max(font.size || 14, 1);
  node.letterSpacing = { value: font.letterSpacing || 0, unit: 'PIXELS' };
  node.lineHeight = font.lineHeight
    ? { value: font.lineHeight, unit: 'PIXELS' }
    : { unit: 'AUTO' };

  if (font.color) node.fills = [solid(font.color)];

  // `start`/`end` resolve against the run's own direction, which the export
  // records because Arabic screens flip them.
  let align = ALIGN[layer.align];
  if (!align) {
    const rtl = layer.dir === 'rtl';
    if (layer.align === 'start') align = rtl ? 'RIGHT' : 'LEFT';
    else if (layer.align === 'end') align = rtl ? 'LEFT' : 'RIGHT';
    else align = 'LEFT';
  }
  node.textAlignHorizontal = align;
  node.textAlignVertical = 'TOP';

  if (font.underline) node.textDecoration = 'UNDERLINE';
  else if (font.strike) node.textDecoration = 'STRIKETHROUGH';

  // Fixed box, not auto-sized: the exported width and height are the ones
  // Flutter's line breaker produced, and letting Figma re-flow the text would
  // move every following baseline.
  node.textAutoResize = 'NONE';
  place(node, layer);

  return node;
}

// ── Images ───────────────────────────────────────────────────────────────

const FIT = {
  cover: 'FILL',
  fill: 'FILL',
  contain: 'FIT',
  scaleDown: 'FIT',
  none: 'FIT',
  fitWidth: 'FIT',
  fitHeight: 'FIT',
};

function buildImage(layer, images) {
  const hash = images[layer.image];
  const node = figma.createRectangle();
  place(node, layer);

  if (hash) {
    node.fills = [{
      type: 'IMAGE',
      imageHash: hash,
      scaleMode: FIT[layer.fit] || 'FIT',
    }];
  } else {
    node.fills = layer.tint ? [solid(layer.tint)] : [];
  }

  applyRadius(node, layer);
  return node;
}

// ── Fonts ────────────────────────────────────────────────────────────────

// The app bundles its faces as `.ttf` under asset-style names; Figma knows
// them by their Google Fonts names.
const FONT_NAMES = {
  SpaceGrotesk: 'Space Grotesk',
  IBMPlexSansArabic: 'IBM Plex Sans Arabic',
  JetBrainsMono: 'JetBrains Mono',
};

const WEIGHTS = {
  100: 'Thin',
  200: 'ExtraLight',
  300: 'Light',
  400: 'Regular',
  500: 'Medium',
  600: 'SemiBold',
  700: 'Bold',
  800: 'ExtraBold',
  900: 'Black',
};

const fontCache = {};
const missingFonts = {};

/// Resolves a Flutter family + numeric weight to a font Figma actually has.
///
/// Falls back rather than throwing, because one missing weight would
/// otherwise abort the whole import at whichever screen happened to use it.
/// Every substitution is reported once, so the user knows to install the real
/// face and re-run rather than wondering why the type looks wrong.
async function resolveFont(family, weight) {
  const key = family + '|' + weight;
  if (fontCache[key]) return fontCache[key];

  const name = FONT_NAMES[family] || family || 'Inter';
  const style = WEIGHTS[weight] || 'Regular';

  const candidates = [
    { family: name, style: style },
    { family: name, style: 'Regular' },
    { family: 'Inter', style: style },
    { family: 'Inter', style: 'Regular' },
  ];

  for (const candidate of candidates) {
    try {
      await figma.loadFontAsync(candidate);
      if (candidate.family !== name && !missingFonts[name]) {
        missingFonts[name] = true;
        post('warn', name + ' is not installed — substituted ' +
          candidate.family + '. Install it and re-run for exact type.');
      }
      fontCache[key] = candidate;
      return candidate;
    } catch (error) {
      // Try the next candidate.
    }
  }

  const last = { family: 'Inter', style: 'Regular' };
  fontCache[key] = last;
  return last;
}

// ── Paint helpers ────────────────────────────────────────────────────────

/// `#RRGGBBAA` → Figma's 0–1 channels. Alpha is carried separately because
/// Figma splits it out of the colour on paints (`opacity`) but keeps it on the
/// colour for variables and effects.
function parseHex(hex) {
  const raw = String(hex || '#000000FF').replace('#', '');
  const r = parseInt(raw.slice(0, 2), 16) / 255;
  const g = parseInt(raw.slice(2, 4), 16) / 255;
  const b = parseInt(raw.slice(4, 6), 16) / 255;
  const a = raw.length >= 8 ? parseInt(raw.slice(6, 8), 16) / 255 : 1;
  return { r: r || 0, g: g || 0, b: b || 0, a: isNaN(a) ? 1 : a };
}

function solid(hex) {
  const c = parseHex(hex);
  return {
    type: 'SOLID',
    color: { r: c.r, g: c.g, b: c.b },
    opacity: c.a,
  };
}

function rgba(hex) {
  const c = parseHex(hex);
  return { r: c.r, g: c.g, b: c.b, a: c.a };
}

function dropShadow(shadow) {
  const c = parseHex(shadow.color);
  return {
    type: shadow.inner ? 'INNER_SHADOW' : 'DROP_SHADOW',
    color: { r: c.r, g: c.g, b: c.b, a: c.a },
    offset: { x: shadow.dx || 0, y: shadow.dy || 0 },
    radius: shadow.blur || 0,
    spread: shadow.spread || 0,
    visible: true,
    blendMode: 'NORMAL',
  };
}

function gradientPaint(gradient) {
  if (!gradient) return null;
  // Radial and sweep gradients do not survive the two-point mapping below.
  // The export flags them; here they collapse to a linear run through the
  // same stops, which is visibly an approximation rather than a wrong-looking
  // exact answer.
  if (gradient.kind === 'linear') return linearGradient(gradient);
  return linearGradient({
    from: [0, 0],
    to: [1, 1],
    colors: gradient.colors,
    stops: gradient.stops,
  });
}

/// Builds Figma's `gradientTransform` from the two endpoints the export
/// recorded, both in the box's own 0–1 space.
///
/// Figma evaluates a linear gradient along x from 0 to 1 *after* applying this
/// matrix, so the matrix has to send `from` to x=0 and `to` to x=1. Row 0 is
/// the projection onto the gradient direction that does exactly that; row 1 is
/// its perpendicular, present only so the matrix stays invertible — Figma
/// ignores y for a linear gradient.
function linearGradient(gradient) {
  const from = gradient.from || [0, 0];
  const to = gradient.to || [1, 1];

  let dx = to[0] - from[0];
  let dy = to[1] - from[1];
  let lengthSquared = dx * dx + dy * dy;

  // A zero-length gradient (both handles on the same point) has no direction
  // to project onto; top-left → bottom-right is the app's own default.
  if (lengthSquared < 1e-9) {
    dx = 1;
    dy = 1;
    lengthSquared = 2;
  }

  const a = dx / lengthSquared;
  const b = dy / lengthSquared;
  const c = -(from[0] * dx + from[1] * dy) / lengthSquared;

  const colors = gradient.colors || [];
  const stops = gradient.stops || [];

  return {
    type: 'GRADIENT_LINEAR',
    gradientTransform: [
      [a, b, c],
      [-b, a, (from[0] * dy - from[1] * dx) / lengthSquared],
    ],
    gradientStops: colors.map((hex, i) => {
      const color = parseHex(hex);
      const position = typeof stops[i] === 'number'
        ? stops[i]
        : (colors.length > 1 ? i / (colors.length - 1) : 0);
      return {
        position: Math.min(Math.max(position, 0), 1),
        color: { r: color.r, g: color.g, b: color.b, a: color.a },
      };
    }),
  };
}
