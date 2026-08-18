import 'package:flutter/material.dart';

import '../../core/theme/app_gradients.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_sizes.dart';

/// The standard 64×3 gradient grab handle shown at the top of every bottom
/// sheet. Centralized here so the four sheets that used to hand-roll the
/// exact same `Container` stay pixel-identical and change in one place.
///
/// Not wrapped in a [Center] — callers decide alignment (most already sit
/// inside a stretched Column, so a bare centered child is what they want).
class SheetDragHandle extends StatelessWidget {
  const SheetDragHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: AppControlSizes.dragHandleWidth,
        height: AppControlSizes.dragHandleHeight,
        decoration: const BoxDecoration(
          gradient: AppGradients.primaryCta,
          borderRadius: AppRadius.pillR,
        ),
      ),
    );
  }
}
