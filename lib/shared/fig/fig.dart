import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_radius.dart';
import '../../core/constants/asset_paths.dart';
import '../extensions/context_extensions.dart';
import '../../core/theme/app_sizes.dart';

/// Design tokens + primitives for the 2026-11 Figma redesign
/// (`figma-design/`). Everything the new screens share lives here so a value
/// seen in the mock is written exactly once.
class Fig {
  Fig._();

  // ── Colours (sampled from the PNG exports) ──────────────────────────
  static const pageGrey = Color(0xFFEEEEEF);
  static const ink = Color(0xFF111827);
  static const navy = Color(0xFF1B2140);
  static const muted = Color(0xFF4A5274);
  static const mutedSoft = Color(0xFF5F6888);
  static const placeholder = Color(0xFF656E8E);
  static const blue = Color(0xFF235FE7);
  static const blueTop = Color(0xFF1D50D9);
  static const blueBottom = Color(0xFF357AF3);
  static const fieldBorder = Color(0xFFB3C3F4);
  static const cardFill = Color(0xFFF8F9FA);
  static const danger = Color(0xFFE5604A);
  static const dangerText = Color(0xFFD9503C);
  static const success = Color(0xFF22C58B);
  static const nearBlack = Color(0xFF08090B);
  static const chipBlue = Color(0xFF3A6FF0);
  static const iconTile = Color(0xFFDDE3F3);
  static const tileText = Color(0xFF3B4268);

  // ── Shared one-offs promoted from screens (same hex, now named) ──
  /// Heading ink on the account rows.
  static const inkDeep = Color(0xFF0B0B0C);

  /// Link / selection accent on dark panels.
  static const accentBlue = Color(0xFF4C8DFF);

  /// Hairline border of the chat rail.
  static const hairline = Color(0xFFD7DBE8);

  /// Soft brand blue (toggles, chips).
  static const blueSoft = Color(0xFF3B6FF0);

  /// Secondary copy on the Apps cards.
  static const mutedGrey = Color(0xFF666B80);

  /// Primary action blue.
  static const blueStrong = Color(0xFF2F63F0);

  /// Selected-row tint.
  static const tintBlue = Color(0xFFE7EDFC);

  /// Secondary copy in the notifications inbox.
  static const mutedCool = Color(0xFF636A80);

  /// Border of tinted blue cards.
  static const borderBlue = Color(0xFFDCE3F6);

  /// Slate icon / badge base.
  static const slate = Color(0xFF6E7BB0);

  /// Tertiary copy.
  static const mutedLight = Color(0xFF7D8190);

  /// Bright brand blue (viewer actions).
  static const blueBright = Color(0xFF3B6FF5);

  /// Dark panel behind code / bars.
  static const darkPanel = Color(0xFF16181C);

  /// Deep navy pill.
  static const navyDeep = Color(0xFF0E1830);

  /// Body text on light sheets.
  static const navyText = Color(0xFF2F3760);

  /// Light panel fill.
  static const panelTint = Color(0xFFF4F5FA);

  /// Light panel border.
  static const panelBorder = Color(0xFFE1E5F1);

  /// Inactive icon blue-grey.
  static const mutedBlue = Color(0xFF5E678A);

  /// Switch track, on.
  static const switchOn = Color(0xFF2F7BF5);

  /// Text shadow ink.
  static const shadowInk = Color(0x990B1230);

  /// Dim copy on the plans page.
  static const mutedDim = Color(0xFF6A7088);

  /// Composer action blue.
  static const blueAction = Color(0xFF2F6BF0);

  /// PDF attachment tint.
  static const fileRed = Color(0xFFFF6B7A);

  /// Document attachment tint.
  static const fileBlue = Color(0xFF3B8BFF);

  /// Spreadsheet attachment tint.
  static const fileGreen = Color(0xFF4CD28F);

  /// Archive attachment tint.
  static const fileAmber = Color(0xFFF3B93C);

  /// Drop shadow of the rail drawer.
  static const drawerShadow = Color(0x33101840);

  /// Cool divider.
  static const dividerCool = Color(0xFFE3E6EF);

  /// Soft divider.
  static const dividerSoft = Color(0xFFE7E8EE);

  /// Near-black text on Home.
  static const inkBlack = Color(0xFF0D0D10);

  /// Indigo-grey copy on Home.
  static const mutedIndigo = Color(0xFF4F5C8A);

  /// Plain near-black.
  static const inkPlain = Color(0xFF111111);

  /// Focus / selected blue on setup forms.
  static const blueFocus = Color(0xFF3B7BF5);

  /// Cool surface in light mode.
  static const surfaceCool = Color(0xFFEFF1F6);

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
              height: 585.0 * stretch,
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
    Color(0xFF080909),
    Color(0xFF090a0d),
    Color(0xFF090a0e),
    Color(0xFF08090e),
    Color(0xFF090a10),
    Color(0xFF0e1529),
    Color(0xFF132142),
    Color(0xFF182d5a),
    Color(0xFF1d3972),
    Color(0xFF21438b),
    Color(0xFF244994),
    Color(0xFF1e3d7a),
    Color(0xFF193161),
    Color(0xFF142547),
    Color(0xFF101a2e),
    Color(0xFF0a0e14),
    Color(0xFF080909),
    Color(0xFF080909),
  ];
  static const _right = [
    Color(0xFF080909),
    Color(0xFF0a0d14),
    Color(0xFF101936),
    Color(0xFF152658),
    Color(0xFF1b337a),
    Color(0xFF2245a6),
    Color(0xFF2953ca),
    Color(0xFF2e5fe8),
    Color(0xFF3166fd),
    Color(0xFF3062ef),
    Color(0xFF2e5ee1),
    Color(0xFF2b56c8),
    Color(0xFF2449a7),
    Color(0xFF1e397f),
    Color(0xFF152750),
    Color(0xFF0b101a),
    Color(0xFF080909),
    Color(0xFF080909),
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
              colors: [Color(0x00FFFFFF), Color(0xFFFFFFFF)],
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
        ? Colors.white.withValues(alpha: 0.14)
        : Fig.fieldBorder;
    final fill = dark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.white.withValues(alpha: 0.34);
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
                size: 16,
                color:
                    widget.labelColor ?? (dark ? Colors.white : Fig.navyText),
                weight: dark ? FontWeight.w600 : FontWeight.w400,
                height: 1.2,
              ),
            ),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(widget.height / 2),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              height: widget.height,
              padding: const EdgeInsetsDirectional.only(
                start: AppSpacing.s20,
                end: AppSpacing.s16,
              ),
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(widget.height / 2),
                border: Border.all(color: borderColor, width: 1),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      focusNode: widget.focusNode,
                      enabled: widget.enabled,
                      obscureText: _hidden,
                      keyboardType: widget.keyboardType,
                      textInputAction: widget.textInputAction,
                      autofillHints: widget.autofillHints,
                      onChanged: widget.onChanged,
                      onSubmitted: widget.onSubmitted,
                      cursorColor: Fig.blue,
                      style: Fig.t(
                        context,
                        size: 14,
                        color:
                            widget.textStyleColor ??
                            (dark ? Colors.white : Fig.navy),
                      ),
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        hintText: widget.hint,
                        hintStyle: Fig.t(
                          context,
                          size: 14,
                          color: dark
                              ? Colors.white.withValues(alpha: 0.8)
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
                          size: 20,
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
                size: 11,
                color: Fig.dangerText,
                height: 1.3,
              ),
            ),
          ),
      ],
    );
  }
}

/// Primary pill CTA (blue vertical gradient). [loading] swaps the label for
/// a spinner and blocks taps.
class FigButton extends StatelessWidget {
  const FigButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.height = 54,
    this.danger = false,
    this.secondary = false,
    this.textColor,
    this.weight = FontWeight.w400,
    this.fontSize = 16,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final double height;
  final bool danger;
  final bool secondary;
  final Color? textColor;
  final FontWeight weight;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    BoxDecoration deco;
    Color fg;
    if (secondary) {
      deco = BoxDecoration(
        color: const Color(0xFFEFF2FC),
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(color: Fig.borderBlue),
      );
      fg = textColor ?? Fig.navy;
    } else if (danger) {
      deco = BoxDecoration(
        color: Fig.danger,
        borderRadius: BorderRadius.circular(height / 2),
      );
      fg = Colors.white;
    } else {
      deco = BoxDecoration(
        gradient: Fig.primaryGradient,
        borderRadius: BorderRadius.circular(height / 2),
      );
      fg = Colors.white;
    }
    return Opacity(
      opacity: onPressed == null ? 0.6 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(height / 2),
          child: Ink(
            height: height,
            decoration: deco,
            child: Center(
              child: loading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: fg,
                      ),
                    )
                  : Text(
                      label,
                      style: Fig.t(
                        context,
                        size: fontSize,
                        color: fg,
                        weight: secondary ? FontWeight.w600 : weight,
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
        width: 90,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Text(
          label,
          style: Fig.t(context, size: 13, color: Colors.white),
        ),
      ),
    );
  }
}

/// White chevron-back used on the dark header region.
class FigBackButton extends StatelessWidget {
  const FigBackButton({super.key, this.onTap, this.color = Colors.white});

  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap ?? () => Navigator.maybePop(context),
      child: SizedBox(
        width: 44,
        height: 44,
        child: Icon(context.chevronBack, color: color, size: 26),
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
              start: 12,
              top: 29,
              bottom: 10,
            ),
            child: FigBackButton(onTap: onBack),
          )
        else
          const SizedBox(height: 62),
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
                    size: 9,
                    color: Colors.white.withValues(alpha: 0.8),
                    letterSpacing: 0.3,
                  ),
                ),
              Text(
                title,
                style: Fig.t(
                  context,
                  size: 28,
                  weight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.s2),
                  child: Text(
                    subtitle!,
                    style: Fig.t(
                      context,
                      size: 9.5,
                      color: Colors.white.withValues(alpha: 0.8),
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
    this.onMore,
  });

  final int index;
  final ValueChanged<int> onSelect;
  final bool showMore;
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
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(31),
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
                              constraints: const BoxConstraints(minWidth: 40),
                              padding: EdgeInsets.symmetric(
                                horizontal: i == index && showLabel
                                    ? AppSpacing.s10
                                    : 0,
                              ),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: i == index
                                    ? Colors.white
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(23),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _icons[i],
                                    size: 20,
                                    color: i == index
                                        ? Colors.black
                                        : Colors.white.withValues(alpha: 0.62),
                                  ),
                                  if (i == index && showLabel) ...[
                                    const SizedBox(width: AppSpacing.s6),
                                    Text(
                                      _labels(context)[i],
                                      maxLines: 1,
                                      style: Fig.t(
                                        context,
                                        size: 12,
                                        weight: FontWeight.w600,
                                        color: Colors.black,
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
                const SizedBox(width: 0),
                Semantics(
                  button: true,
                  label: context.tr.figMore,
                  excludeSemantics: true,
                  onTap: onMore,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onMore,
                    child: Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(31),
                      ),
                      child: const Icon(
                        LucideIcons.ellipsisVertical,
                        size: 18,
                        color: Colors.white,
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
              padding: const EdgeInsets.only(top: 40),
              child: child,
            ),
          ),
        ),
        Positioned(
          top: 0,
          child: GestureDetector(
            onTap: onClose ?? () => Navigator.maybePop(context),
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: dark ? Fig.darkPanel : Fig.surfaceCool,
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.x,
                size: 24,
                color: dark ? Colors.white : Colors.black,
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
    barrierColor: Colors.black.withValues(alpha: 0.45),
    useSafeArea: true,
    // Root navigator: the sheet must cover the floating tab bar, which lives
    // in the shell above the inner navigator (it hid the primary button).
    useRootNavigator: true,
    builder: builder,
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
        colors: const [Color(0x00FFFFFF), Color(0xFFFFFFFF)],
        stops: [0, (height / rect.height).clamp(0.0, 1.0)],
      ).createShader(rect),
      child: child,
    );
  }
}
