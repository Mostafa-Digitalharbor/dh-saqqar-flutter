import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/app_radius.dart';
import '../extensions/context_extensions.dart';
import '../../core/theme/app_sizes.dart';

/// Spec §5.1 glass panel — translucent fill + 1px border, with an optional
/// 14px backdrop blur.
///
/// **[blur] defaults to `false`.** A `BackdropFilter` blurs whatever is
/// painted *behind* it, and in this app that is always `AmbientBackground`,
/// which paints a flat opaque `bg` fill — `withBlobs: true` has no call site
/// anywhere in `lib/`. Blurring a uniform colour returns the same uniform
/// colour, so the filter renders an identical frame while still forcing an
/// offscreen `saveLayer` plus a gaussian pass, per card, per frame — cost
/// that is invisible on a flagship and shows up as dropped frames on a
/// low-end GPU.
///
/// Every production call site had already worked around this by passing
/// `blur: false` by hand; defaulting it off means a new card can't
/// accidentally opt into a no-op blur just by not knowing to. The parameter
/// stays so the effect can be switched back on for a surface that genuinely
/// sits over varied content (a sheet over the chat transcript, or the ambient
/// blobs if they are ever re-enabled) — that is where blur reads as glass
/// rather than as a no-op.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    this.padding = const EdgeInsets.all(AppSpacing.s16),
    this.margin,
    this.borderRadius = AppRadius.cardR,
    this.blur = false,
    this.color,
    this.borderColor,
    this.clipBehavior = Clip.none,
    this.child,
  }) : _elevated = true;

  /// The same fill, border and radius with **no drop shadow**.
  ///
  /// This is the surface a card already sitting inside another card wants —
  /// a row in a list that is itself on a panel, a suggestion pill, an inline
  /// hint. Stacking [GlassCard]'s shadow inside a parent that already casts
  /// one reads as grime around the inner edge rather than as depth, which is
  /// why every one of these sites had hand-rolled the `Container` +
  /// `BoxDecoration` instead of using the shared card. Seven copies of the
  /// same three lines meant `cardBg`/`cardBorder` could drift apart per
  /// screen, and none of them picked up the radius token when it moved.
  ///
  /// Pass [borderRadius] as `AppRadius.pillR` for the pill-shaped variant.
  const GlassCard.flat({
    super.key,
    this.padding = const EdgeInsets.all(AppSpacing.s16),
    this.margin,
    this.borderRadius = AppRadius.cardR,
    this.color,
    this.borderColor,
    this.clipBehavior = Clip.none,
    this.child,
  })  : blur = false,
        _elevated = false;

  final EdgeInsetsGeometry padding;

  /// Outer inset. Kept on the card rather than left to a wrapping `Padding`
  /// so a call site that needs both reads as one widget.
  final EdgeInsetsGeometry? margin;

  final BorderRadius borderRadius;
  final Color? color;
  final Color? borderColor;

  /// Set to `true` only when this card actually sits over varied content —
  /// see the class doc for why the default is off.
  final bool blur;

  /// Whether the card casts the elevation shadow. `false` for [GlassCard.flat].
  final bool _elevated;

  /// Clips the child to [borderRadius]. Needed when the child paints to the
  /// edge — an `InkWell` ripple, an image, a progress bar — which would
  /// otherwise square off the corners the border draws round.
  final Clip clipBehavior;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;

    final body = Container(
      padding: padding,
      margin: margin,
      clipBehavior: clipBehavior,
      decoration: BoxDecoration(
        color: color ?? s.cardBg,
        borderRadius: borderRadius,
        border: Border.all(color: borderColor ?? s.cardBorder),
        // Tightened shadows, deliberately NOT `s.glassShadow`: the design
        // system's 28/30-blur float bled beyond every card and read as haze
        // rather than depth once cards were stacked in a list. The hue is the
        // shared token; only the blur/offset are local.
        boxShadow: !_elevated
            ? null
            : context.isDark
                ? [
                    BoxShadow(
                      color: s.shadowBase.withValues(alpha: AppAlphas.a35),
                      blurRadius: AppShadowSizes.blurCard,
                      offset: const Offset(0, AppShadowSizes.dropCard),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: s.shadowBase.withValues(alpha: AppAlphas.a06),
                      blurRadius: AppShadowSizes.blurHairline,
                      offset: const Offset(0, AppShadowSizes.dropHairline),
                    ),
                  ],
      ),
      child: child,
    );

    if (!blur) return body;

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: AppShadowSizes.glassBlurSigma, sigmaY: AppShadowSizes.glassBlurSigma),
        child: body,
      ),
    );
  }
}
