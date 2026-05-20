import 'package:flutter/widgets.dart';

/// Wraps [child] in a `MediaQuery` that forces a fixed [scale] regardless
/// of the user's OS Dynamic Type setting.
///
/// The Saqqar shell honours the system text scale globally (clamped to
/// 0.85–1.4 in `app.dart`) so body copy and headings grow with the user's
/// preference. **Dense surfaces** — uppercase badges, mini-pill toggles,
/// meta dots — are designed at a single typographic size and don't
/// survive 1.4× scaling without wrapping or clipping. Wrap those
/// specific surfaces in this widget so their geometry stays predictable
/// while everything else around them still respects the system setting.
///
/// Default is `1.0` (no scaling). Pass a different value only when a
/// surface should be allowed a *little* bit of growth.
class TextScaleLock extends StatelessWidget {
  const TextScaleLock({super.key, required this.child, this.scale = 1.0});

  final Widget child;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(textScaler: TextScaler.linear(scale)),
      child: child,
    );
  }
}
