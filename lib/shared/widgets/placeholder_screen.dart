import 'package:flutter/material.dart';

import '../../core/i18n/app_localizations.dart';
import '../extensions/context_extensions.dart';
import 'eyebrow_label.dart';

/// Used by feature screens that haven't been built yet (Sprints 2+).
/// Shows the screen title + a one-liner so the navigation shell is testable
/// from day one.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title, this.caption});

  final String title;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              EyebrowLabel(context.tr.placeholder),
              const SizedBox(height: 12),
              Text(title, style: context.text.headlineMedium),
              if (caption != null) ...[
                const SizedBox(height: 8),
                Text(
                  caption!,
                  textAlign: TextAlign.center,
                  style: (context.text.bodyMedium ?? const TextStyle())
                      .copyWith(color: s.muted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
