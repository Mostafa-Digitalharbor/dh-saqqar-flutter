import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/constants/ui_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_sizes.dart';

/// Friendly fallback for uncaught widget build errors.
///
/// Replaces Flutter's default red [ErrorWidget] (which is fine in debug
/// but terrifying in production). Shows a warning icon + generic message,
/// and exposes the underlying exception when debugging — never to end
/// users in release.
///
/// Wired once at boot via:
/// ```dart
/// ErrorWidget.builder = (details) => AppErrorScreen(details: details);
/// ```
class AppErrorScreen extends StatelessWidget {
  const AppErrorScreen({super.key, required this.details});

  final FlutterErrorDetails details;

  /// Resolves the app's strings WITHOUT throwing.
  ///
  /// This widget is `ErrorWidget.builder` — the handler of last resort. If
  /// it throws, Flutter re-enters the error path and the user gets a broken
  /// screen instead of this one, so every lookup here has to degrade rather
  /// than fail. `AppLocalizations.of` asserts non-null and would do exactly
  /// the wrong thing; the raw `Localizations.of` returns null when this
  /// mounts above the app's Localizations scope (which is the very case the
  /// English fallbacks below exist for).
  static AppStrings? _stringsOrNull(BuildContext context) {
    try {
      return Localizations.of<AppLocalizations>(
        context,
        AppLocalizations,
      )?.strings;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // We can't read the app THEME reliably here — this widget can mount
    // before MaterialApp's theme is in scope — so pin a dark neutral
    // palette that always renders something sensible.
    //
    // These are `AppColors` members rather than raw hexes on purpose:
    // they're plain `static const`, so naming them costs no BuildContext
    // and keeps the crash screen on the brand palette instead of quietly
    // drifting from it. Do NOT swap these for `context.saqqar` lookups —
    // that's the part that isn't safe here.
    const bg = AppColors.darkBg;
    const card = AppColors.darkSurface;
    const danger = AppColors.danger;
    const muted = AppColors.darkMuted;

    // Localized when the app's scope survived the error, English when it
    // didn't. The English here must match `crash_screen_*` in app_strings.
    final tr = _stringsOrNull(context);
    final title = tr?.crashScreenTitle ?? 'Something went wrong';
    final body =
        tr?.crashScreenBody ??
        'This screen ran into a problem. The error has been '
            'logged. Try going back, or restart the app if it '
            'keeps happening.';

    // `Text` needs a Directionality ancestor and there's no guarantee one is
    // in scope here. Prefer the ambient direction; otherwise derive it from
    // the locale we resolved, and fall back to LTR.
    final direction =
        Directionality.maybeOf(context) ??
        (tr != null && tr.isArabic ? TextDirection.rtl : TextDirection.ltr);

    return Directionality(
      textDirection: direction,
      child: Material(
        color: bg,
        child: SafeArea(
          // Scrollable, and deliberately so on the one screen with no other
          // way out. This is `ErrorWidget.builder` — it renders after the app
          // has already failed once, so an overflow here replaces the
          // explanation for a broken screen with a second broken screen.
          //
          // It overflowed by 17 px on a 320x568 phone in English at 1.0x
          // text: the smallest supported device at the DEFAULT type size,
          // not an edge case. `minHeight: constraints.maxHeight` keeps the
          // card centred while it fits and lets it scroll once it does not,
          // so the common case looks exactly as it did.
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppLayoutWidths.errorCard,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.s32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: AppBoxSizes.errorGlyph,
                            height: AppBoxSizes.errorGlyph,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: danger.withValues(alpha: AppAlphas.a14),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: danger.withValues(alpha: AppAlphas.a32),
                              ),
                            ),
                            child: const Icon(
                              AppIcons.warning,
                              color: danger,
                              size: AppIconSizes.crash,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s18),
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.onBrand,
                              fontSize: AppFontSizes.crashTitle,
                              fontWeight: FontWeight.w900,
                              letterSpacing: AppLetterSpacing.heading,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s8),
                          Text(
                            body,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: muted,
                              height: AppLineHeights.reading,
                              fontSize: AppFontSizes.body,
                            ),
                          ),
                          if (kDebugMode) ...[
                            const SizedBox(height: AppSpacing.s18),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(AppSpacing.s12),
                              decoration: BoxDecoration(
                                color: card,
                                borderRadius: AppRadius.smallR,
                                border: Border.all(
                                  color: muted.withValues(alpha: AppAlphas.a20),
                                ),
                              ),
                              child: SelectableText(
                                details.exceptionAsString(),
                                style: const TextStyle(
                                  color: muted,
                                  fontFamily: UiStrings.monospaceFontFamily,
                                  fontSize: AppFontSizes.footnote,
                                  height: AppLineHeights.compact,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Programmatic restart: pops everything to the root, then re-pushes a
/// fresh route. Doesn't truly restart the Dart isolate (that's a heavier
/// operation requiring the `restart_app` package), but visually achieves
/// the same effect for most error-recovery cases.
///
/// Called from the recovery action on [AppErrorScreen] (when wired with
/// a navigator key — left out by default because errors thrown from
/// inside `build` can break navigator state).
class AppRestart {
  AppRestart._();

  /// Hard restart by re-running `main()`. Best-effort — won't work for
  /// errors that survive a runApp() call (e.g. corrupted singletons).
  static void hardRestart() {
    // The cheapest visual restart that doesn't require a separate
    // package: signal the system to throw away the current activity so
    // the OS restores the app. iOS ignores this; Android uses it.
    SystemNavigator.pop();
  }
}
