import 'package:flutter/material.dart';

/// Everything below the transcript — the conditional banners and the composer
/// — bounded so it can never push the chat off its own screen.
///
/// **The bug this exists for.** `ChatScreen`'s body is a `Column` of fixed
/// chrome around one `Expanded` message list: header controls, offline banner,
/// run-progress card, the list, then the env hint, the quota banner, the
/// suggestion strip and the composer. `Expanded` shrinks to zero but not
/// below, so once the *fixed* children alone exceed the body the column
/// overflows — and every banner is conditional, so the tall case only appears
/// when several fire together.
///
/// Measured on a 320×568 phone at 1.3× text with a near-limit quota banner:
/// header 54 + banners 218 + composer 232 against 504 of body. The overflow
/// stripe landed across the composer, painting the send button off-screen.
///
/// **Landscape is not the edge case — the keyboard is.** The device matrix
/// catches this at 568×320, but the same arithmetic runs every time someone
/// taps the composer on a small phone: the keyboard takes the bottom half,
/// `MediaQuery.viewInsets` shrinks the body to roughly landscape height, and
/// the chrome is suddenly taller than the space left. That is the ordinary
/// case of using the app, not a rotation nobody performs.
///
/// **Why bounded-and-scrollable rather than hiding something.** Nothing here
/// is decoration: the quota banner is the only warning before sends start
/// failing, and the env hint is the one-tap fix for a chat that cannot run at
/// all. Dropping one to save pixels hides exactly the message the user needs.
///
/// `reverse: true` is what makes scrolling the right answer instead of a
/// compromise — the view rests at its *end*, so the composer is always the
/// part on screen and the banners are what scroll away. The user never has to
/// discover a scroll to reach the send button.
///
/// **It is inert on a normal screen.** A `SingleChildScrollView` under a
/// `maxHeight` constraint sizes to its content whenever the content fits, so
/// on any viewport where this band already fit, the layout is unchanged to the
/// pixel and nothing becomes scrollable.
class ChatBottomChrome extends StatelessWidget {
  const ChatBottomChrome({
    super.key,
    required this.maxHeight,
    required this.children,
  });

  /// Hard ceiling for the whole band, in logical pixels.
  ///
  /// Callers pass a fraction of the **body** height from a `LayoutBuilder`,
  /// not of the screen: the screen does not shrink when the keyboard opens,
  /// and the keyboard is the case that matters. See [fractionOfBody].
  final double maxHeight;

  /// The banners in order, composer last.
  final List<Widget> children;

  /// Share of the body this band may take before it starts scrolling.
  ///
  /// 0.75 keeps a quarter of the body for the transcript in the worst cell
  /// while leaving the band enough room that no ordinary phone ever scrolls
  /// it. Named rather than inlined so the sweep and the screen cannot drift
  /// to two different numbers.
  static const fractionOfBody = 0.75;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
        reverse: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }
}
