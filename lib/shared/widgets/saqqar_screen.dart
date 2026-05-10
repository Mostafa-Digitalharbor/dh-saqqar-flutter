import 'package:flutter/material.dart';

import '../extensions/context_extensions.dart';
import 'ambient_background.dart';
import 'responsive_content.dart';

class SaqqarScreen extends StatelessWidget {
  const SaqqarScreen({
    super.key,
    required this.children,
    this.controller,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 28),
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
    final list = ListView(
      controller: controller,
      padding: EdgeInsets.zero,
      physics: onRefresh != null
          ? const AlwaysScrollableScrollPhysics()
          : physics,
      children: [
        ResponsiveContent(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
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
