import 'package:flutter/cupertino.dart' show CupertinoIcons;
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
  static const IconData chevronsLeft = LucideIcons.chevronsLeft;
  static const IconData chevronDown = LucideIcons.chevronDown;
  static const IconData chevronUp = LucideIcons.chevronUp;
  static const IconData arrowRight = LucideIcons.arrowRight;
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
  static const IconData signIn = LucideIcons.logIn;
  static const IconData signOut = LucideIcons.logOut;
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
}
