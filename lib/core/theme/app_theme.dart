import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_icons.dart';
import 'app_radius.dart';
import 'app_sizes.dart';
import 'app_typography.dart';
import 'saqqar_theme_extension.dart';

/// Builds [ThemeData] for the app, parameterized by [Brightness] and [Locale].
///
/// The locale is a parameter (not derived from `MaterialApp`) so that the
/// font family swaps deterministically with the locale instead of via a
/// runtime `WidgetsBinding.instance.platformDispatcher.locale` lookup.
class AppTheme {
  AppTheme._();

  static ThemeData light(Locale locale) => _build(Brightness.light, locale);
  static ThemeData dark(Locale locale) => _build(Brightness.dark, locale);

  static ThemeData _build(Brightness brightness, Locale locale) {
    final isDark = brightness == Brightness.dark;

    final ext = SaqqarThemeExtension(
      bg: isDark ? AppColors.darkBg : AppColors.lightBg,
      surface: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      surface2: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
      surface3: isDark ? AppColors.darkSurface3 : AppColors.lightSurface3,
      text: isDark ? AppColors.darkText : AppColors.lightText,
      muted: isDark ? AppColors.darkMuted : AppColors.lightMuted,
      border: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      cardBg: isDark ? AppColors.darkCardBg : AppColors.lightCardBg,
      cardBorder: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
      hoverBg: isDark ? AppColors.darkHoverBg : AppColors.lightHoverBg,
      brandCyan: AppColors.brandCyan,
      brandCyanStrong: AppColors.brandCyanStrong,
      brandPurple: AppColors.brandPurple,
      brandNavy: AppColors.brandNavy,
      success: AppColors.success,
      warning: AppColors.warning,
      danger: AppColors.danger,
      brandCyanSoft: isDark
          ? AppColors.brandCyanSoftDark
          : AppColors.brandCyanSoftLight,
      brandCyanBorder: AppColors.brandCyanBorder,
      overlay: isDark ? AppColors.overlayDark : AppColors.overlayLight,
      codePlate: isDark ? AppColors.codePlateDark : AppColors.codePlateLight,
    );

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.brandCyan,
      onPrimary: Colors.white,
      secondary: AppColors.brandPurple,
      onSecondary: Colors.white,
      tertiary: AppColors.brandNavy,
      onTertiary: Colors.white,
      error: AppColors.danger,
      onError: Colors.white,
      surface: ext.surface,
      onSurface: ext.text,
      surfaceContainer: ext.surface2,
      surfaceContainerHigh: ext.surface3,
      outline: ext.border,
      outlineVariant: ext.cardBorder,
    );

    final textTheme = AppTypography.scale(
      locale: locale,
      text: ext.text,
      muted: ext.muted,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: ext.bg,
      canvasColor: ext.bg,
      textTheme: textTheme,
      iconTheme: IconThemeData(color: ext.text, size: AppIconSizes.action),
      dividerTheme: DividerThemeData(color: ext.border, thickness: 1, space: 1),
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.adaptivePlatformDensity,

      // Force the iPhone-style back chevron for EVERY back affordance on
      // every platform — the auto AppBar leading, BackButton, etc. Without
      // this, Android would render Material's arrow_back while iOS shows the
      // chevron; the builder pins one look everywhere.
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (context) =>
            const Icon(AppIcons.backIos, size: AppIconSizes.back),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: ext.surface.withValues(alpha: isDark ? 0.88 : 0.96),
        foregroundColor: ext.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 60,
        centerTitle: false,
        titleTextStyle: (textTheme.titleLarge ?? const TextStyle()).copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
          color: ext.text,
        ),
        iconTheme: IconThemeData(color: ext.text, size: AppIconSizes.navBar),
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        shape: Border(bottom: BorderSide(color: ext.border, width: 1)),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: ext.surface,
        selectedItemColor: AppColors.brandCyan,
        unselectedItemColor: ext.muted,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        elevation: 0,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: AppColors.brandCyan.withValues(alpha: 0.16),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.brandCyan : ext.muted,
            size: AppIconSizes.navBar,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return (textTheme.labelSmall ?? const TextStyle()).copyWith(
            color: selected ? AppColors.brandCyan : ext.muted,
            letterSpacing: 0,
          );
        }),
        height: 68,
      ),

      cardTheme: CardThemeData(
        color: ext.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardR,
          side: BorderSide(color: ext.cardBorder),
        ),
        margin: EdgeInsets.zero,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: ext.surface2,
        selectedColor: AppColors.brandCyan.withValues(
          alpha: isDark ? 0.20 : 0.14,
        ),
        disabledColor: ext.surface2.withValues(alpha: 0.55),
        checkmarkColor: AppColors.brandCyan,
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s10,
          vertical: AppSpacing.s8,
        ),
        labelStyle: (textTheme.labelMedium ?? const TextStyle()).copyWith(
          color: ext.text,
        ),
        secondaryLabelStyle: (textTheme.labelMedium ?? const TextStyle())
            .copyWith(color: AppColors.brandCyan, fontWeight: FontWeight.w700),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.pillR),
        side: BorderSide(color: ext.border),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.brandNavy,
        foregroundColor: Colors.white,
        elevation: 6,
        focusElevation: 6,
        hoverElevation: 8,
        highlightElevation: 6,
        shape: const StadiumBorder(),
        extendedTextStyle: (textTheme.labelLarge ?? const TextStyle()).copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: ext.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.inputR,
          side: BorderSide(color: ext.border),
        ),
        textStyle: textTheme.bodyMedium,
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.brandCyan.withValues(
                alpha: isDark ? 0.22 : 0.16,
              );
            }
            return ext.surface2;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.brandCyan;
            }
            return ext.text;
          }),
          side: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return BorderSide(
              color: selected
                  ? AppColors.brandCyan.withValues(alpha: 0.45)
                  : ext.border,
            );
          }),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(
              horizontal: AppSpacing.s12,
              vertical: AppSpacing.s10,
            ),
          ),
          textStyle: WidgetStateProperty.all(textTheme.labelMedium),
          shape: WidgetStateProperty.all(
            const RoundedRectangleBorder(borderRadius: AppRadius.buttonR),
          ),
        ),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: ext.muted,
        titleTextStyle: textTheme.titleSmall,
        subtitleTextStyle: textTheme.bodySmall?.copyWith(color: ext.muted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s12,
          vertical: AppSpacing.s4,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ext.surface2,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s14,
          vertical: AppSpacing.s14,
        ),
        hintStyle: (textTheme.bodyMedium ?? const TextStyle()).copyWith(
          color: ext.muted,
        ),
        labelStyle: (textTheme.bodyMedium ?? const TextStyle()).copyWith(
          color: ext.muted,
        ),
        helperStyle: (textTheme.labelSmall ?? const TextStyle()).copyWith(
          color: ext.muted,
        ),
        errorStyle: (textTheme.labelSmall ?? const TextStyle()).copyWith(
          color: AppColors.danger,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.inputR,
          borderSide: BorderSide(color: ext.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputR,
          borderSide: BorderSide(color: ext.cardBorder),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AppRadius.inputR,
          borderSide: BorderSide(color: AppColors.brandCyan, width: 1.5),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: AppRadius.inputR,
          borderSide: BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: AppRadius.inputR,
          borderSide: BorderSide(color: AppColors.danger, width: 1.5),
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return ext.muted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.brandCyan;
          return ext.surface3;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: ext.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.modalR),
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyMedium,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: ext.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetTopR),
        showDragHandle: true,
        dragHandleColor: ext.muted,
        modalBarrierColor: ext.overlay,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: ext.surface,
        contentTextStyle: textTheme.bodyMedium,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.toastR),
        elevation: 0,
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: ext.surface3,
          borderRadius: AppRadius.toastR,
          border: Border.all(color: ext.border),
        ),
        textStyle: (textTheme.labelSmall ?? const TextStyle()).copyWith(
          color: ext.text,
        ),
      ),

      extensions: [ext],
    );
  }
}
