import 'package:flutter/material.dart';

import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../core/theme/app_radius.dart';

/// Pill-shaped floating action button used on the Conversations screen.
/// Gradient fill + cyan glow shadow + leading [AppIcons.plus] glyph.
class GradientFab extends StatelessWidget {
  const GradientFab({
    super.key,
    required this.onPressed,
    required this.label,
  });

  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Material(
      color: Colors.transparent,
      borderRadius: AppRadius.pillR,
      child: InkWell(
        onTap: onPressed,
        borderRadius: AppRadius.pillR,
        child: Ink(
          padding: const EdgeInsetsDirectional.fromSTEB(18, 14, 22, 14),
          decoration: BoxDecoration(
            gradient: AppGradients.primaryCta,
            borderRadius: AppRadius.pillR,
            boxShadow: [
              BoxShadow(
                color: s.brandCyan.withValues(alpha: 0.36),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(AppIcons.plus, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              // `mainAxisSize.min` keeps the pill hugging its label, but it
              // does NOT stop the label itself from exceeding the incoming
              // width — an extended FAB with a long label ("New
              // conversation" / "محادثة جديدة") overflowed a 320 px screen
              // by 42 px at 1.3× text. `Flexible` lets the label give way
              // there while keeping the pill at its natural size everywhere
              // else. Safe because both call sites mount this as a
              // `Scaffold.floatingActionButton`, which lays it out against
              // bounded (screen-sized) constraints.
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
