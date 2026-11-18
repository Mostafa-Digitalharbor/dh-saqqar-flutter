/// Figma-redesign metrics that have no home in the main design-token classes.
///
/// The redesign was drawn on a pixel grid of its own, so some values (a 13 px
/// label, a 0.42 scrim) sit between the steps `AppSizes` publishes. They are
/// named here, by kind and value, rather than typed at the call site — so the
/// number still lives in exactly one const file and a re-tune is one edit.
/// Prefer an `AppSizes` token whenever one matches; add here only when none does.
class FigMetrics {
  FigMetrics._();

  static const double alphaA24 = 0.24;
  static const double fontFig5U5 = 5.5;
  static const double fontFig8 = 8;
  static const double fontFig8U5 = 8.5;
  static const double fontFig9 = 9;
  static const double fontFig9U5 = 9.5;
  static const double fontFig10 = 10;
  static const double fontFig10U5 = 10.5;
  static const double fontFig11 = 11;
  static const double fontFig11U5 = 11.5;
  static const double fontFig21 = 21;
  static const double fontFig23 = 23;
  static const double fontFig26 = 26;
  static const double fontFig29 = 29;
  static const double fontFig30 = 30;
  static const double fontFig32 = 32;
  static const double fontFig36 = 36;
  static const double fontFig46 = 46;
  static const double iconFig74 = 74;
  static const double lsFign1U4 = -1.4;
  static const double lsFig0U9 = 0.9;
  static const double lhFig104 = 1.04;
  static const double lhFig108 = 1.08;
  static const double lhFig117 = 1.17;
  static const double lhFig585 = 585;
  static const double bwFig1U2 = 1.2;
  static const double bwFig1U6 = 1.6;
  static const double radFig3 = 3;
  static const double radFig5 = 5;
  static const double radFig9 = 9;
  static const double radFig13 = 13;
  static const double radFig15 = 15;
  static const double radFig17 = 17;
  static const double radFig19 = 19;
  static const double radFig21 = 21;
  static const double radFig23 = 23;
  static const double radFig24 = 24;
  static const double radFig25 = 25;
  static const double radFig27 = 27;
  static const double radFig30 = 30;
  static const double radFig31 = 31;
  static const double radFig32 = 32;
  static const double radFig33 = 33;
  static const double radFig40 = 40;

  // Shadow, constraint and stroke geometry of the redesign, named by value.
  static const double blur14 = 14;
  static const double blur16 = 16;
  static const double blur40 = 40;
  static const double blur6 = 6;
  static const double boxMAxWU62 = 62;
  static const double boxMAxWU70 = 70;
  static const double boxMInHU46 = 46;
  static const double boxMInHU56 = 56;
  static const double boxMInHU68 = 68;
  static const double boxMInWU40 = 40;
  static const double font16 = 16;
  static const double sigma14 = 14;
  static const double sigma8 = 8;
  static const double size1 = 1;
  static const double size10 = 10;
  static const double size16 = 16;
  static const double size18 = 18;
  static const double size20 = 20;
  static const double size22 = 22;
  static const double size220 = 220;
  static const double size24 = 24;
  static const double size28 = 28;
  static const double size30 = 30;
  static const double size32 = 32;
  static const double size36 = 36;
  static const double size38 = 38;
  static const double size40 = 40;
  static const double size42 = 42;
  static const double size44 = 44;
  static const double size46 = 46;
  static const double size48 = 48;
  static const double size5 = 5;
  static const double size54 = 54;
  static const double size56 = 56;
  static const double size6 = 6;
  static const double size60 = 60;
  static const double size62 = 62;
  static const double size66 = 66;
  static const double size7 = 7;
  static const double size74 = 74;
  static const double size8 = 8;
  static const double size9 = 9;
  static const double size90 = 90;
}
