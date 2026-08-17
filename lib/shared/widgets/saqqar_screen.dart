import 'package:flutter/material.dart';

import '../extensions/context_extensions.dart';
import 'ambient_background.dart';
import '../../core/theme/app_sizes.dart';

class SaqqarScreen extends StatelessWidget {
  const SaqqarScreen({
    super.key,
    required this.children,
    this.controller,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.s16,
      AppSpacing.s16,
      AppSpacing.s16,
      AppSpacing.s28,
    ),
    this.physics,
    this.onRefresh,
  });

  final List<Widget> children;
  final ScrollController? controller;
  final EdgeInsetsGeometry padding;
  final ScrollPhysics? physics;

  /// If provided, a [RefreshIndicator] wraps the list and runs this callback
  /// when the user pulls down past the threshold.
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    // Resolve the page padding once. Vertical insets go on the list itself
    // (a single SliverPadding, applied top + bottom); horizontal insets and
    // the max-width centering are re-applied per row below.
    final resolved = padding.resolve(Directionality.of(context));

    // LAZY list. The screen used to nest EVERY child in one `Column` under a
    // single `ListView` child, which defeated the builder entirely: all rows
    // (e.g. 30 conversation cards, each with a blurred shadow) were built,
    // laid out, and painted up front, with no viewport culling and — because
    // there was only one sliver child — no automatic per-row RepaintBoundary.
    // Rendering each child through `itemBuilder` restores culling AND gives
    // every row its own RepaintBoundary, so a card's shadow raster is cached
    // and off-screen rows cost nothing. This is the single biggest scroll win.
    final list = ListView.builder(
      controller: controller,
      padding: EdgeInsets.only(top: resolved.top, bottom: resolved.bottom),
      physics: onRefresh != null
          ? const AlwaysScrollableScrollPhysics()
          : physics,
      // Pre-render ~1.5 screenfuls of off-screen rows so flick-scroll
      // never reveals a row that wasn't built yet — user explicitly
      // asked for the "everything was already there" feel.
      cacheExtent: 1500,
      itemCount: children.length,
      itemBuilder: (context, i) => Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.only(left: resolved.left, right: resolved.right),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            // `width: infinity` reproduces the old Column's
            // `crossAxisAlignment.stretch` so cards fill the content column
            // instead of shrink-wrapping to their own width.
            child: SizedBox(width: double.infinity, child: children[i]),
          ),
        ),
      ),
    );

    final body = onRefresh == null
        ? list
        : RefreshIndicator(
            onRefresh: onRefresh!,
            color: context.saqqar.brandCyan,
            backgroundColor: context.saqqar.surface,
            displacement: 24,
            child: list,
          );

    return AmbientBackground(child: body);
  }
}
