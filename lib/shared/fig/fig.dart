import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/constants/asset_paths.dart';
import '../extensions/context_extensions.dart';
import '../../core/theme/app_sizes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/fig_metrics.dart';

/// Design tokens + primitives for the 2026-11 Figma redesign
/// (`figma-design/`). Everything the new screens share lives here so a value
/// seen in the mock is written exactly once.
class Fig {
  Fig._();

  // ── Colours (sampled from the PNG exports) ──────────────────────────
  static const pageGrey = AppColors.figPageGrey;
  static const ink = AppColors.figInk;
  static const navy = AppColors.figNavy;
  static const muted = AppColors.figMuted;
  static const mutedSoft = AppColors.figMutedSoft;
  static const placeholder = AppColors.figPlaceholder;
  static const blue = AppColors.figBlue;
  static const blueTop = AppColors.figBlueTop;
  static const blueBottom = AppColors.figBlueBottom;
  static const fieldBorder = AppColors.figFieldBorder;
  static const cardFill = AppColors.figCardFill;
  static const danger = AppColors.figDanger;
  static const dangerText = AppColors.figDangerText;
  static const success = AppColors.figSuccess;
  static const nearBlack = AppColors.figNearBlack;
  static const chipBlue = AppColors.figChipBlue;
  static const iconTile = AppColors.figIconTile;
  static const tileText = AppColors.figTileText;

  // ── Shared one-offs promoted from screens (same hex, now named) ──
  /// Heading ink on the account rows.
  static const inkDeep = AppColors.figInkDeep;

  /// Link / selection accent on dark panels.
  static const accentBlue = AppColors.figAccentBlue;

  /// Hairline border of the chat rail.
  static const hairline = AppColors.figHairline;

  /// Soft brand blue (toggles, chips).
  static const blueSoft = AppColors.figBlueSoft;

  /// Secondary copy on the Apps cards.
  static const mutedGrey = AppColors.figMutedGrey;

  /// Primary action blue.
  static const blueStrong = AppColors.figBlueStrong;

  /// Selected-row tint.
  static const tintBlue = AppColors.figTintBlue;

  /// Secondary copy in the notifications inbox.
  static const mutedCool = AppColors.figMutedCool;

  /// Border of tinted blue cards.
  static const borderBlue = AppColors.figBorderBlue;

  /// Slate icon / badge base.
  static const slate = AppColors.figSlate;

  /// Tertiary copy.
  static const mutedLight = AppColors.figMutedLight;

  /// Bright brand blue (viewer actions).
  static const blueBright = AppColors.figBlueBright;

  /// Dark panel behind code / bars.
  static const darkPanel = AppColors.figDarkPanel;

  /// Deep navy pill.
  static const navyDeep = AppColors.figNavyDeep;

  /// Body text on light sheets.
  static const navyText = AppColors.figNavyText;

  /// Light panel fill.
  static const panelTint = AppColors.figPanelTint;

  /// Light panel border.
  static const panelBorder = AppColors.figPanelBorder;

  /// Inactive icon blue-grey.
  static const mutedBlue = AppColors.figMutedBlue;

  /// Switch track, on.
  static const switchOn = AppColors.figSwitchOn;

  /// Text shadow ink.
  static const shadowInk = AppColors.figShadowInk;

  /// Dim copy on the plans page.
  static const mutedDim = AppColors.figMutedDim;

  /// Composer action blue.
  static const blueAction = AppColors.figBlueAction;

  /// PDF attachment tint.
  static const fileRed = AppColors.figFileRed;

  /// Document attachment tint.
  static const fileBlue = AppColors.figFileBlue;

  /// Spreadsheet attachment tint.
  static const fileGreen = AppColors.figFileGreen;

  /// Archive attachment tint.
  static const fileAmber = AppColors.figFileAmber;

  /// Drop shadow of the rail drawer.
  static const drawerShadow = AppColors.figDrawerShadow;

  /// Cool divider.
  static const dividerCool = AppColors.figDividerCool;

  /// Soft divider.
  static const dividerSoft = AppColors.figDividerSoft;

  /// Near-black text on Home.
  static const inkBlack = AppColors.figInkBlack;

  /// Indigo-grey copy on Home.
  static const mutedIndigo = AppColors.figMutedIndigo;

  /// Plain near-black.
  static const inkPlain = AppColors.figInkPlain;

  /// Focus / selected blue on setup forms.
  static const blueFocus = AppColors.figBlueFocus;

  /// Cool surface in light mode.
  static const surfaceCool = AppColors.figSurfaceCool;

  static const radiusPill = 30.0;
  static const radiusCard = 26.0;

  /// The type ramp the mock was drawn at runs 8-16, which is too small to
  /// read comfortably on a real phone (and shrinks again with a user's text
  /// scale). [t] lifts it in one place: nothing is drawn below [minFontSize],
  /// and the body range (up to 16) goes up one point so captions, rows and
  /// headings keep their relative order. 17 and above is left as designed.
  static const minFontSize = 13.0;

  static double scaled(double size) {
    if (size < minFontSize) return minFontSize;
    return size < 17 ? size + 1 : size;
  }

  /// Locale-aware text style (Hanken Grotesk for Latin, Tajawal for Arabic).
  static TextStyle t(
    BuildContext context, {
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = ink,
    double? height,
    double letterSpacing = 0,
  }) {
    final base = Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
    return base.copyWith(
      fontSize: scaled(size),
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static const primaryGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [blueTop, blueBottom],
  );
}

/// The page backdrop: black → electric blue glow → #EEEEEF. The artwork is
/// the clean gradient lifted from the mock (`AssetPaths.backdropLight`).
class FigBackdrop extends StatelessWidget {
  const FigBackdrop({
    super.key,
    required this.child,
    this.dark = false,
    this.stretch = 1.0,
  });

  final Widget child;

  /// Dark variant used by the chat surface.
  final bool dark;

  /// Vertical stretch of the glow artwork; the tall Profile frames in the
  /// mock use ~1.12.
  final double stretch;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: dark ? Fig.nearBlack : Fig.pageGrey),
        if (dark)
          const Positioned.fill(child: _ChatGlow())
        else
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            // Stretch to the width, but keep the height in logical pixels:
            // the mock's content is laid out in dp, so the glow has to stay
            // put against it on wider phones instead of growing with them.
            child: Image.asset(
              AssetPaths.backdropLight,
              fit: BoxFit.fill,
              height: FigMetrics.lhFig585 * stretch,
              width: double.infinity,
              filterQuality: FilterQuality.medium,
              gaplessPlayback: true,
            ),
          ),
        child,
      ],
    );
  }
}

class _ChatGlow extends StatelessWidget {
  const _ChatGlow();

  // Sampled from the mock's left and right edges (figma-design/Chat-Screen):
  // the glow is a vertical band that is brighter and starts higher on the
  // right, blended horizontally. Stops are fractions of the 713px chat card.
  static const _stops = <double>[
    0.0,
    0.1234,
    0.1711,
    0.2188,
    0.2665,
    0.3142,
    0.3619,
    0.4095,
    0.4572,
    0.5049,
    0.5526,
    0.6003,
    0.6480,
    0.6957,
    0.7433,
    0.7910,
    0.8387,
    1.0,
  ];
  static const _left = [
    AppColors.figCFF080909,
    AppColors.figCFF090A0D,
    AppColors.figCFF090A0E,
    AppColors.figCFF08090E,
    AppColors.figCFF090A10,
    AppColors.figCFF0E1529,
    AppColors.figCFF132142,
    AppColors.figCFF182D5A,
    AppColors.figCFF1D3972,
    AppColors.figCFF21438B,
    AppColors.figCFF244994,
    AppColors.figCFF1E3D7A,
    AppColors.figCFF193161,
    AppColors.figCFF142547,
    AppColors.figCFF101A2E,
    AppColors.figCFF0A0E14,
    AppColors.figCFF080909,
    AppColors.figCFF080909,
  ];
  static const _right = [
    AppColors.figCFF080909,
    AppColors.figCFF0A0D14,
    AppColors.figCFF101936,
    AppColors.figCFF152658,
    AppColors.figCFF1B337A,
    AppColors.figCFF2245A6,
    AppColors.figCFF2953CA,
    AppColors.figCFF2E5FE8,
    AppColors.figCFF3166FD,
    AppColors.figCFF3062EF,
    AppColors.figCFF2E5EE1,
    AppColors.figCFF2B56C8,
    AppColors.figCFF2449A7,
    AppColors.figCFF1E397F,
    AppColors.figCFF152750,
    AppColors.figCFF0B101A,
    AppColors.figCFF080909,
    AppColors.figCFF080909,
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: _stops,
                colors: _left,
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (r) => const LinearGradient(
              colors: [AppColors.figC00FFFFFF, AppColors.figCFFFFFFFF],
              stops: [0.2, 0.8],
            ).createShader(r),
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: _stops,
                  colors: _right,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Glass text field — label above, pill field, optional eye toggle and an
/// inline error under it (red border + red caption, as in the validation
/// frames).
class FigField extends StatefulWidget {
  const FigField({
    super.key,
    required this.label,
    required this.hint,
    this.controller,
    this.obscure = false,
    this.error,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.autofillHints,
    this.dark = false,
    this.labelColor,
    this.focusNode,
    this.enabled = true,
    this.trailing,
    this.height = 54,
    this.textStyleColor,
  });

  final String label;
  final String hint;
  final TextEditingController? controller;
  final bool obscure;
  final String? error;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;
  final bool dark;
  final Color? labelColor;
  final FocusNode? focusNode;
  final bool enabled;
  final Widget? trailing;
  final double height;
  final Color? textStyleColor;

  @override
  State<FigField> createState() => _FigFieldState();
}

class _FigFieldState extends State<FigField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    final hasError = widget.error != null;
    final dark = widget.dark;
    final borderColor = hasError
        ? Fig.danger
        : dark
        ? AppColors.figWhite.withValues(alpha: AppAlphas.a14)
        : Fig.fieldBorder;
    final fill = dark
        ? AppColors.figWhite.withValues(alpha: AppAlphas.a05)
        : AppColors.figWhite.withValues(alpha: AppAlphas.a34);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label.isNotEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.s2),
            child: Text(
              widget.label,
              style: Fig.t(
                context,
                size: AppFontSizes.reading,
                color:
                    widget.labelColor ?? (dark ? AppColors.figWhite : Fig.navyText),
                weight: dark ? FontWeight.w600 : FontWeight.w400,
                height: AppLineHeights.heading,
              ),
            ),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(widget.height / 2),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: FigMetrics.sigma8, sigmaY: FigMetrics.sigma8),
            child: Container(
              height: widget.height,
              padding: const EdgeInsetsDirectional.only(
                start: AppSpacing.s20,
                end: AppSpacing.s16,
              ),
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(widget.height / 2),
                border: Border.all(color: borderColor, width: AppBorderWidths.hairline),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      focusNode: widget.focusNode,
                      enabled: widget.enabled,
                      obscureText: _hidden,
                      textAlignVertical: TextAlignVertical.center,
                      keyboardType: widget.keyboardType,
                      textInputAction: widget.textInputAction,
                      autofillHints: widget.autofillHints,
                      onChanged: widget.onChanged,
                      onSubmitted: widget.onSubmitted,
                      cursorColor: Fig.blue,
                      style: Fig.t(
                        context,
                        size: AppFontSizes.dense,
                        color:
                            widget.textStyleColor ??
                            (dark ? AppColors.figWhite : Fig.navy),
                      ),
                      decoration: InputDecoration(
                        isCollapsed: true,
                        // The app theme pads inputs by 14; left in, that sat
                        // the text 14 further in than the mock's pill.
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        hintText: widget.hint,
                        hintStyle: Fig.t(
                          context,
                          size: AppFontSizes.dense,
                          color: dark
                              ? AppColors.figWhite.withValues(alpha: AppAlphas.a80)
                              : Fig.placeholder,
                        ),
                      ),
                    ),
                  ),
                  if (widget.obscure)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _hidden = !_hidden),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.s4),
                        child: Icon(
                          _hidden ? LucideIcons.eye : LucideIcons.eyeOff,
                          size: AppIconSizes.action,
                          color: Fig.muted,
                        ),
                      ),
                    ),
                  if (widget.trailing != null) widget.trailing!,
                ],
              ),
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsetsDirectional.only(
              top: AppSpacing.s6,
              start: AppSpacing.s2,
            ),
            child: Text(
              widget.error!,
              style: Fig.t(
                context,
                size: FigMetrics.fontFig11,
                color: Fig.dangerText,
                height: AppLineHeights.snug,
              ),
            ),
          ),
      ],
    );
  }
}

/// Primary pill CTA (blue vertical gradient). [loading] swaps the label for
/// a spinner and blocks taps.
///
/// One button for the whole app: [secondary] is the light outlined pill,
/// [danger] the solid red one and [dangerOutline] the red-tinted outline for
/// destructive but not final actions. [FigButton.compact] is the in-card size.
class FigButton extends StatelessWidget {
  const FigButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.height = 54,
    this.danger = false,
    this.dangerOutline = false,
    this.secondary = false,
    this.textColor,
    this.weight = FontWeight.w400,
    this.fontSize = FigMetrics.font16,
    this.icon,
    this.expand = true,
  }) : keepLabelWhileLoading = false;

  /// The size used inside cards, rows and dialogs: shorter, semi-bold and
  /// only as wide as its content unless [expand] says otherwise.
  const FigButton.compact({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.height = FigMetrics.size46,
    this.danger = false,
    this.dangerOutline = false,
    this.secondary = false,
    this.textColor,
    this.icon,
    this.expand = false,
  }) : weight = FontWeight.w600,
       fontSize = AppFontSizes.dense,
       keepLabelWhileLoading = true;

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  /// Minimum height; a label that wraps to two lines grows the button.
  final double height;
  final bool danger;
  final bool dangerOutline;
  final bool secondary;
  final Color? textColor;
  final FontWeight weight;
  final double fontSize;
  final IconData? icon;

  /// Fill the available width (true) or hug the content (false).
  final bool expand;

  /// Whether the label stays next to the spinner while [loading] — in cards
  /// the label often changes to say what is happening ("Resuming…").
  final bool keepLabelWhileLoading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final radius = BorderRadius.circular(height / 2);
    BoxDecoration deco;
    Color fg;
    if (dangerOutline) {
      deco = BoxDecoration(
        color: Fig.danger.withValues(alpha: AppAlphas.a10),
        borderRadius: radius,
        border: Border.all(color: Fig.danger.withValues(alpha: AppAlphas.a40)),
      );
      fg = Fig.danger;
    } else if (secondary) {
      final onDark = FigDarkSurface.of(context);
      deco = BoxDecoration(
        color: onDark
            ? AppColors.figWhite.withValues(alpha: AppAlphas.a08)
            : AppColors.figCFFEFF2FC,
        borderRadius: radius,
        border: Border.all(
          color: onDark
              ? AppColors.figWhite.withValues(alpha: AppAlphas.a18)
              : Fig.borderBlue,
        ),
      );
      fg = textColor ?? (onDark ? AppColors.figWhite : Fig.navy);
    } else if (danger) {
      deco = BoxDecoration(color: Fig.danger, borderRadius: radius);
      fg = AppColors.figWhite;
    } else {
      deco = BoxDecoration(
        gradient: Fig.primaryGradient,
        borderRadius: radius,
      );
      fg = AppColors.figWhite;
    }
    final text = Text(
      label,
      // Two lines, not one: in a half-width dialog button a longer label was
      // cut to "Send to li…", hiding the word that says what the button does.
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: Fig.t(
        context,
        size: fontSize,
        color: fg,
        weight: secondary || dangerOutline ? FontWeight.w600 : weight,
      ),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Opacity(
        opacity: onPressed == null ? 0.6 : 1,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: radius,
            child: Ink(
              decoration: deco,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: height),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s18,
                    vertical: AppSpacing.s8,
                  ),
                  child: ExcludeSemantics(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                      children: [
                        if (loading) ...[
                          SizedBox(
                            width: FigMetrics.size22,
                            height: FigMetrics.size22,
                            child: CircularProgressIndicator(
                              strokeWidth: AppStrokeWidths.spinnerSnug,
                              color: fg,
                            ),
                          ),
                          if (keepLabelWhileLoading)
                            const SizedBox(width: AppSpacing.s10),
                        ] else if (icon != null) ...[
                          Icon(icon, size: AppIconSizes.regular, color: fg),
                          const SizedBox(width: AppSpacing.s10),
                        ],
                        if (!loading || keepLabelWhileLoading)
                          Flexible(child: text),
                      ],
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

/// Small translucent pill in a page's top corner ("Sign Up" / "Sign In").
class FigTopPill extends StatelessWidget {
  const FigTopPill({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: FigMetrics.size90, height: FigMetrics.size36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.figWhite.withValues(alpha: AppAlphas.a10),
          borderRadius: BorderRadius.circular(AppRadius.modal),
          border: Border.all(color: AppColors.figWhite.withValues(alpha: AppAlphas.a18)),
        ),
        child: Text(
          label,
          style: Fig.t(context, size: AppFontSizes.caption, color: AppColors.figWhite),
        ),
      ),
    );
  }
}

/// White chevron-back used on the dark header region.
class FigBackButton extends StatelessWidget {
  const FigBackButton({super.key, this.onTap, this.color = AppColors.figWhite});

  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap ?? () => Navigator.maybePop(context),
      child: SizedBox(
        width: FigMetrics.size44, height: FigMetrics.size44,
        child: Icon(context.chevronBack, color: color, size: AppIconSizes.tile),
      ),
    );
  }
}

/// Page header used by Profile / Billing / Saqqar Apps: back chevron,
/// optional eyebrow, big white title and optional subtitle.
class FigPageHeader extends StatelessWidget {
  const FigPageHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.onBack,
    this.showBack = true,
  });

  final String title;
  final String? eyebrow;
  final String? subtitle;
  final VoidCallback? onBack;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showBack)
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: AppSpacing.s12,
              top: AppSpacing.s29,
              bottom: AppSpacing.s10,
            ),
            child: FigBackButton(onTap: onBack),
          )
        else
          const SizedBox(height: AppSpacing.s62),
        Padding(
          padding: const EdgeInsetsDirectional.only(
            start: AppSpacing.s24,
            end: AppSpacing.s24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null)
                Text(
                  eyebrow!,
                  style: Fig.t(
                    context,
                    size: FigMetrics.fontFig9,
                    color: AppColors.figWhite.withValues(alpha: AppAlphas.a80),
                    letterSpacing: AppLetterSpacing.snug,
                  ),
                ),
              Text(
                title,
                style: Fig.t(
                  context,
                  size: AppFontSizes.displayLarge,
                  weight: FontWeight.w700,
                  color: AppColors.figWhite,
                  height: AppLineHeights.heading,
                ),
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.s2),
                  child: Text(
                    subtitle!,
                    style: Fig.t(
                      context,
                      size: FigMetrics.fontFig9U5,
                      color: AppColors.figWhite.withValues(alpha: AppAlphas.a80),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The floating black pill tab bar. [index] 0..3 = Home / Chat / Apps / Tasks;
/// [showMore] adds the detached ⋮ pill the mock shows on every tab but Home.
class FigNavBar extends StatelessWidget {
  const FigNavBar({
    super.key,
    required this.index,
    required this.onSelect,
    this.showMore = true,
    this.moreSelected = false,
    this.onMore,
  });

  final int index;
  final ValueChanged<int> onSelect;
  final bool showMore;

  /// True while a screen opened from the ⋮ menu is showing, so the ⋮ pill
  /// (not a tab) carries the "you are here" highlight.
  final bool moreSelected;
  final VoidCallback? onMore;

  static const _icons = [
    LucideIcons.house,
    LucideIcons.sparkles,
    LucideIcons.layoutGrid,
    LucideIcons.listChecks,
  ];

  static List<String> _labels(BuildContext c) => [
    c.tr.figHome,
    c.tr.figChat,
    c.tr.figApps2,
    c.tr.figTasks,
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // The label needs ~70dp more than the bare icons; on a very narrow
        // phone the bar falls back to icons only rather than overflowing.
        final showLabel = constraints.maxWidth >= 344;
        return MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.15,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 62,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6),
                decoration: BoxDecoration(
                  color: AppColors.figBlack,
                  borderRadius: BorderRadius.circular(FigMetrics.radFig31),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < _icons.length; i++)
                      Semantics(
                        button: true,
                        selected: i == index,
                        label: _labels(context)[i],
                        excludeSemantics: true,
                        onTap: () => onSelect(i),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onSelect(i),
                          // The selected tab names itself; the others stay compact.
                          // `AnimatedSize` rather than a fixed width so the label
                          // can never overflow mid-transition.
                          child: AnimatedSize(
                            duration: AppDurations.expand,
                            curve: Curves.easeOut,
                            child: Container(
                              height: 46,
                              constraints: const BoxConstraints(minWidth: FigMetrics.boxMInWU40),
                              padding: EdgeInsets.symmetric(
                                horizontal: i == index && showLabel
                                    ? AppSpacing.s10
                                    : 0,
                              ),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: i == index
                                    ? AppColors.figWhite
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(FigMetrics.radFig23),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _icons[i],
                                    size: AppIconSizes.action,
                                    color: i == index
                                        ? AppColors.figBlack
                                        : AppColors.figWhite.withValues(alpha: AppAlphas.a62),
                                  ),
                                  if (i == index && showLabel) ...[
                                    const SizedBox(width: AppSpacing.s6),
                                    Text(
                                      _labels(context)[i],
                                      maxLines: 1,
                                      style: Fig.t(
                                        context,
                                        size: AppFontSizes.microCaps,
                                        weight: FontWeight.w600,
                                        color: AppColors.figBlack,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (showMore) ...[
                const SizedBox(width: AppSpacing.zero),
                Semantics(
                  button: true,
                  label: context.tr.figMore,
                  excludeSemantics: true,
                  onTap: onMore,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onMore,
                    child: Container(
                      width: FigMetrics.size62, height: FigMetrics.size62,
                      decoration: BoxDecoration(
                        color: AppColors.figBlack,
                        borderRadius: BorderRadius.circular(FigMetrics.radFig31),
                      ),
                      child: Center(
                        child: AnimatedContainer(
                          duration: AppDurations.expand,
                          width: FigMetrics.boxMInWU40,
                          height: FigMetrics.size46,
                          decoration: BoxDecoration(
                            color: moreSelected
                                ? AppColors.figWhite
                                : Colors.transparent,
                            borderRadius:
                                BorderRadius.circular(FigMetrics.radFig23),
                          ),
                          child: Icon(
                            LucideIcons.ellipsisVertical,
                            size: AppIconSizes.regular,
                            color: moreSelected
                                ? AppColors.figBlack
                                : AppColors.figWhite,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Bottom-sheet / dialog shell with the notch + circular close button used
/// by the light dialogs (sign out, delete account, schedule task…).
class FigNotchSheet extends StatelessWidget {
  const FigNotchSheet({
    super.key,
    required this.child,
    this.dark = false,
    this.onClose,
  });

  final Widget child;
  final bool dark;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final bg = dark ? Fig.darkPanel : Fig.surfaceCool;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.s30),
          child: ClipPath(
            clipper: _NotchClipper(),
            child: Container(
              width: double.infinity,
              color: bg,
              padding: const EdgeInsets.only(top: AppSpacing.s40),
              child: child,
            ),
          ),
        ),
        Positioned(
          top: 0,
          child: GestureDetector(
            onTap: onClose ?? () => Navigator.maybePop(context),
            child: Container(
              width: FigMetrics.size60, height: FigMetrics.size60,
              decoration: BoxDecoration(
                color: dark ? Fig.darkPanel : Fig.surfaceCool,
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.x,
                size: AppIconSizes.back,
                color: dark ? AppColors.figWhite : AppColors.figBlack,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NotchClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const r = 28.0;
    const notchR = 36.0;
    final cx = size.width / 2;
    final p = Path()..moveTo(0, r);
    p.quadraticBezierTo(0, 0, r, 0);
    p.lineTo(cx - notchR - 22, 0);
    p.cubicTo(cx - notchR - 4, 0, cx - notchR + 2, 4, cx - notchR + 6, 8);
    p.arcToPoint(
      Offset(cx + notchR - 6, 8),
      radius: const Radius.circular(notchR),
      clockwise: false,
    );
    p.cubicTo(cx + notchR - 2, 4, cx + notchR + 4, 0, cx + notchR + 22, 0);
    p.lineTo(size.width - r, 0);
    p.quadraticBezierTo(size.width, 0, size.width, r);
    p.lineTo(size.width, size.height - r);
    p.quadraticBezierTo(size.width, size.height, size.width - r, size.height);
    p.lineTo(r, size.height);
    p.quadraticBezierTo(0, size.height, 0, size.height - r);
    p.close();
    return p;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Shows [builder] in a transparent modal sheet — the caller supplies the
/// [FigNotchSheet].
Future<T?> showFigSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    // The sheet content is its own rounded surface; the theme's handle
    // would float above it on the transparent route.
    showDragHandle: false,
    barrierColor: AppColors.figBlack.withValues(alpha: AppAlphas.a45),
    useSafeArea: true,
    // Root navigator: the sheet must cover the floating tab bar, which lives
    // in the shell above the inner navigator (it hid the primary button).
    useRootNavigator: true,
    builder: builder,
  );
}

/// Marks a subtree as drawn on a dark Figma surface (the Connections page and
/// everything it opens). Sheets and dialogs shown from inside it come up dark
/// too, so one flow never mixes a dark page with white popups.
///
/// An [InheritedTheme] so `showDialog` / `showModalBottomSheet` carry it into
/// the route they build (they capture themes, not arbitrary inherited widgets).
class FigDarkSurface extends InheritedTheme {
  const FigDarkSurface({super.key, required super.child});

  /// A popup built from the page's own context reads `Theme.of` above the
  /// shell's pinned theme, so the dark theme travels with the marker.
  @override
  Widget wrap(BuildContext context, Widget child) => FigDarkSurface(
    child: Theme(
      data: AppTheme.dark(Localizations.localeOf(context)),
      child: child,
    ),
  );

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FigDarkSurface>() != null;

  @override
  bool updateShouldNotify(FigDarkSurface oldWidget) => false;
}

/// Shows [builder] in a standard modal sheet in the Figma look — white surface,
/// large top radius, drag handle — pinned to the light theme so the regular
/// `context.saqqar` widgets inside stay legible whatever the device theme is.
/// For sheets the Figma set did not draw; drawn ones use [showFigSheet].
Future<T?> showLightSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isScrollControlled = true,
}) {
  final dark = FigDarkSurface.of(context);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: dark ? AppColors.figCFF17181B : AppColors.figWhite,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetTopR),
    showDragHandle: true,
    barrierColor: AppColors.figBlack.withValues(alpha: AppAlphas.a45),
    useSafeArea: true,
    useRootNavigator: true,
    builder: (sheetContext) {
      final locale = Localizations.localeOf(sheetContext);
      final base = dark ? AppTheme.dark(locale) : AppTheme.light(locale);
      return Theme(
        data: base.copyWith(platform: Theme.of(sheetContext).platform),
        child: dark
            ? FigDarkSurface(child: Builder(builder: builder))
            : Builder(builder: builder),
      );
    },
  );
}

/// Light status-bar icons over the dark header region.
const figLightStatusBar = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
);

/// Fades the top edge of a scrolling list out instead of slicing it with a
/// hard line under the status bar. Content at rest is untouched: the fade only
/// covers the first [height] logical pixels of the viewport.
class FigTopFade extends StatelessWidget {
  const FigTopFade({super.key, required this.child, this.height = 28});

  final Widget child;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [AppColors.figC00FFFFFF, AppColors.figCFFFFFFFF],
        stops: [0, (height / rect.height).clamp(0.0, 1.0)],
      ).createShader(rect),
      child: child,
    );
  }
}
