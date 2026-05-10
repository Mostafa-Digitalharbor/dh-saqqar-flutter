import 'package:flutter/material.dart';

class AppRadius {
  AppRadius._();

  static const double card = 20;
  static const double button = 12;
  static const double pill = 999;
  static const double input = 14;
  static const double toast = 12;
  static const double modal = 18;
  static const double sheetTop = 24;
  static const double bubble = 16;
  static const double row = 12;

  // Convenience BorderRadius constants.
  static const BorderRadius cardR = BorderRadius.all(Radius.circular(card));
  static const BorderRadius buttonR = BorderRadius.all(Radius.circular(button));
  static const BorderRadius pillR = BorderRadius.all(Radius.circular(pill));
  static const BorderRadius inputR = BorderRadius.all(Radius.circular(input));
  static const BorderRadius toastR = BorderRadius.all(Radius.circular(toast));
  static const BorderRadius modalR = BorderRadius.all(Radius.circular(modal));
  static const BorderRadius bubbleR = BorderRadius.all(Radius.circular(bubble));
  static const BorderRadius rowR = BorderRadius.all(Radius.circular(row));

  static const BorderRadius sheetTopR = BorderRadius.only(
    topLeft: Radius.circular(sheetTop),
    topRight: Radius.circular(sheetTop),
  );
}

class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}

class AppDurations {
  AppDurations._();

  // Animation timings from §12 of the spec.
  static const Duration cardIn = Duration(milliseconds: 220);
  static const Duration menuIn = Duration(milliseconds: 150);
  static const Duration toastIn = Duration(milliseconds: 250);
  static const Duration listFadeIn = Duration(milliseconds: 400);
  static const Duration pulseDot = Duration(seconds: 2);
  static const Duration scanLine = Duration(milliseconds: 2600);
  static const Duration cursorBlink = Duration(milliseconds: 900);
  static const Duration thinkingDots = Duration(seconds: 1);
  static const Duration themeTransition = Duration(milliseconds: 300);
}
