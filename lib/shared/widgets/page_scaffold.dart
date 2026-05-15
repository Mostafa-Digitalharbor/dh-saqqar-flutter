import 'package:flutter/material.dart';

import '../extensions/context_extensions.dart';
import 'offline_banner.dart';
import 'saqqar_screen.dart';

class PageScaffold extends StatelessWidget {
  const PageScaffold({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.actions,
    this.controller,
    this.floatingActionButton,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 28),
    this.onRefresh,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final List<Widget>? actions;
  final ScrollController? controller;
  final Widget? floatingActionButton;
  final EdgeInsetsGeometry padding;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: subtitle == null
            ? Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelSmall?.copyWith(
                      color: context.saqqar.muted,
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
        actions: actions,
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: SaqqarScreen(
              controller: controller,
              padding: padding,
              onRefresh: onRefresh,
              children: children,
            ),
          ),
        ],
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}
