import 'package:flutter/cupertino.dart' show CupertinoIcons;
// `material` only for the handful of glyphs Lucide has no equivalent for —
// each is commented at its declaration. `widgets` stays for `IconData`.
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class AppIcons {
  AppIcons._();

  /// iPhone-style back chevron. Used app-wide for every back affordance
  /// (AppBar leadings via the theme's [ActionIconThemeData], plus any
  /// explicit back buttons) so navigation looks the same on every platform.
  static const IconData backIos = CupertinoIcons.back;

  static const IconData search = LucideIcons.search;
  static const IconData refresh = LucideIcons.refreshCcw;
  static const IconData plus = LucideIcons.plus;
  static const IconData attach = LucideIcons.paperclip;
  static const IconData trash = LucideIcons.trash;
  static const IconData edit = LucideIcons.squarePen;
  static const IconData share = LucideIcons.share;
  static const IconData archive = LucideIcons.archive;
  static const IconData more = LucideIcons.ellipsisVertical;
  static const IconData check = LucideIcons.check;
  static const IconData close = LucideIcons.x;
  static const IconData chevronLeft = LucideIcons.chevronLeft;
  static const IconData chevronRight = LucideIcons.chevronRight;
  // Double-chevron "jump to first page" affordance for the pagination bar.
  // Both directions exist because the glyph is mirrored in Arabic — read it
  // through `context.chevronsBack` rather than naming a side here.
  static const IconData chevronsLeft = LucideIcons.chevronsLeft;
  static const IconData chevronsRight = LucideIcons.chevronsRight;
  static const IconData chevronDown = LucideIcons.chevronDown;
  static const IconData chevronUp = LucideIcons.chevronUp;
  // Both directions exist because the glyph is mirrored in Arabic — read it
  // through `context.arrowForward` rather than naming a side here.
  static const IconData arrowRight = LucideIcons.arrowRight;
  static const IconData arrowLeft = LucideIcons.arrowLeft;
  static const IconData sun = LucideIcons.sun;
  static const IconData moon = LucideIcons.moon;
  static const IconData globe = LucideIcons.globe;
  static const IconData eye = LucideIcons.eye;
  static const IconData eyeOff = LucideIcons.eyeOff;
  static const IconData lock = LucideIcons.lock;
  static const IconData user = LucideIcons.user;
  static const IconData account = LucideIcons.circleUserRound;
  static const IconData key = LucideIcons.key;
  static const IconData terminal = LucideIcons.terminal;
  static const IconData slash = LucideIcons.slash;
  static const IconData cpu = LucideIcons.cpu;
  static const IconData database = LucideIcons.database;
  static const IconData github = LucideIcons.gitBranch;
  static const IconData sparkles = LucideIcons.sparkles;
  static const IconData lightbulb = LucideIcons.lightbulb;
  static const IconData shield = LucideIcons.shield;
  static const IconData shieldCheck = LucideIcons.shieldCheck;
  static const IconData shieldAlert = LucideIcons.shieldAlert;
  static const IconData download = LucideIcons.download;
  static const IconData fileDown = LucideIcons.fileDown;
  static const IconData warning = LucideIcons.circleAlert;
  static const IconData send = LucideIcons.send;
  /// Filled square — composer "Stop generating" button while the agent is
  /// streaming. Mirrors the web's stop control replacing Send.
  static const IconData stop = LucideIcons.square;
  static const IconData chats = LucideIcons.messageCircle;
  static const IconData message = LucideIcons.messageSquare;
  static const IconData inbox = LucideIcons.inbox;
  static const IconData menu = LucideIcons.menu;
  static const IconData bell = LucideIcons.bell;
  static const IconData files = LucideIcons.folderOpen;
  static const IconData file = LucideIcons.file;
  static const IconData fileText = LucideIcons.fileText;
  static const IconData table = LucideIcons.table2;
  static const IconData image = LucideIcons.image;
  static const IconData camera = LucideIcons.camera;
  static const IconData code = LucideIcons.braces;
  static const IconData grid = LucideIcons.grid2x2;
  static const IconData bolt = LucideIcons.bolt;
  static const IconData bot = LucideIcons.bot;
  static const IconData save = LucideIcons.save;
  static const IconData open = LucideIcons.externalLink;
  // ── The door pair mirrors itself ──────────────────────────────────────
  //
  // These two are NOT each other's mirror, which is what an earlier pass
  // assumed. Lucide draws `log-out` as a door on the LEFT with the arrow
  // travelling right, out of it; and `log-in` as a door on the RIGHT with
  // the arrow *also* travelling right, into it. Same arrow direction, door on
  // opposite sides. Swapping them for RTL therefore does not mirror anything
  // — it changes the meaning, and the Arabic build shipped an ENTER arrow on
  // its Sign out button. Caught by putting the two renders side by side.
  //
  // The mirror of "arrow leaving a door on the left" is "arrow leaving a door
  // on the right", and no Lucide glyph draws that. So the flip is done to the
  // glyph itself: `matchTextDirection` makes Flutter's `Icon` widget apply a
  // horizontal transform under `TextDirection.rtl`, which is exactly the
  // reflection wanted and is free at every call site — a bare
  // `AppIcons.signOut` is now correct in both directions, so there is nothing
  // for a caller to remember.
  //
  // Only these two need it. The chevrons and arrows keep their
  // `context.chevron*` / `context.arrowForward` accessors, because there the
  // left and right constants ARE genuine mirrors and naming the direction is
  // clearer than transforming a glyph.

  // The code points are spelled out because `IconData` has to stay `const`
  // (call sites build const `Icon`s) and Dart will not let a const expression
  // read a field off another const object. `app_icons_direction_test.dart`
  // asserts each one still equals its `LucideIcons` source, so the copy
  // cannot drift when the package renumbers.
  static const String _lucideFamily = 'Lucide';
  static const String _lucidePackage = 'lucide_icons_flutter';

  /// The "enter" door. Mirrors itself in RTL.
  static const IconData signIn = IconData(
    0xe10d, // LucideIcons.logIn
    fontFamily: _lucideFamily,
    fontPackage: _lucidePackage,
    matchTextDirection: true,
  );

  /// The "leave" door. Mirrors itself in RTL.
  static const IconData signOut = IconData(
    0xe10e, // LucideIcons.logOut
    fontFamily: _lucideFamily,
    fontPackage: _lucidePackage,
    matchTextDirection: true,
  );
  static const IconData userPlus = LucideIcons.userPlus;
  static const IconData mail = LucideIcons.mail;
  static const IconData settings = LucideIcons.settings;
  static const IconData palette = LucideIcons.palette;
  static const IconData success = LucideIcons.circleCheck;
  static const IconData error = LucideIcons.circleX;
  static const IconData info = LucideIcons.info;
  static const IconData server = LucideIcons.server;
  static const IconData drive = LucideIcons.hardDrive;
  static const IconData logoMark = LucideIcons.sparkles;
  static const IconData cloudOff = LucideIcons.cloudOff;

  /// Tab icon for the Projects (formerly "Credential Vault") section. A
  /// briefcase reads as "your work projects" universally and is more
  /// semantically right than the old `key` (credentials) glyph now that
  /// the tab is project-centric.
  static const IconData projects = LucideIcons.briefcase;

  /// Heading glyph for the billing group on Account.
  static const IconData wallet = LucideIcons.wallet;

  // ── Added 2026-08-09, closing a drift ───────────────────────────────
  //
  // An audit found 67 raw `Icons.*` references across 24 files. Two thirds
  // of them named a concept this class *already* had — `Icons.error_outline`
  // beside `AppIcons.error`, `Icons.info_outline` beside `AppIcons.info`,
  // `Icons.grid_view_rounded` beside `AppIcons.grid`. So the same idea was
  // rendering in two different icon sets depending on which screen you were
  // on, which is a visible inconsistency rather than only a tidiness one.
  //
  // Those call sites now use the existing constants. The names below cover
  // the concepts this class genuinely did not have yet.
  //
  // A few deliberately stay on Material, and each says why: this class is
  // the single place icons are chosen, not a rule that they must all come
  // from one package.

  static const IconData mic = LucideIcons.mic;
  static const IconData copy = LucideIcons.copy;
  static const IconData play = LucideIcons.play;
  static const IconData pin = LucideIcons.pin;
  static const IconData pinOff = LucideIcons.pinOff;
  static const IconData unarchive = LucideIcons.archiveRestore;
  static const IconData stopCircle = LucideIcons.circleStop;
  static const IconData clock = LucideIcons.clock;
  static const IconData receipt = LucideIcons.receipt;
  static const IconData rocket = LucideIcons.rocket;
  static const IconData premium = LucideIcons.award;
  static const IconData barChart = LucideIcons.chartColumn;
  static const IconData calculator = LucideIcons.calculator;
  static const IconData bank = LucideIcons.landmark;
  static const IconData puzzle = LucideIcons.puzzle;
  static const IconData qa = LucideIcons.messagesSquare;
  static const IconData recordDot = LucideIcons.circleDot;
  static const IconData devices = LucideIcons.monitorSmartphone;
  static const IconData apple = LucideIcons.apple;

  // In-chat app-pulse cards (Task 1, MOBILE_TASKS_2026-09.md) — one icon per
  // guided app, distinct from the coarser group glyphs `apps_screen.dart`
  // uses for the gallery grid.
  static const IconData factory = LucideIcons.factory;
  static const IconData warehouse = LucideIcons.warehouse;
  static const IconData purchasing = LucideIcons.shoppingCart;
  static const IconData hr = LucideIcons.users;

  /// Biometric unlock. **Material on purpose** — Lucide ships no fingerprint
  /// glyph (only `scanFace`, which names one modality), and the app gates on
  /// whichever of Face ID or fingerprint the device offers. The Material
  /// fingerprint is the conventional glyph for "biometrics" generally.
  static const IconData biometric = Icons.fingerprint;

  /// Per-platform device rows in Push settings. **Material on purpose** —
  /// Lucide has a single `smartphone`, and collapsing the two would drop the
  /// only thing that distinguishes an iPhone row from an Android one at a
  /// glance.
  static const IconData deviceIos = Icons.phone_iphone;
  static const IconData deviceAndroid = Icons.phone_android;

  /// Storybook's LTR/RTL preview toggle. **Material on purpose** — a
  /// developer-only surface, and Lucide has no text-direction pair.
  static const IconData textDirLtr = Icons.format_textdirection_l_to_r;
  static const IconData textDirRtl = Icons.format_textdirection_r_to_l;
}
