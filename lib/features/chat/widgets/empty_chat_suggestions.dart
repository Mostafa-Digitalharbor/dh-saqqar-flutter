import 'package:flutter/material.dart';

import '../../../shared/fig/fig.dart';
import '../../home/home_screen.dart' show Orb;
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_sizes.dart';

/// Empty-chat surface: the orb and the centred "Hello `<name>` — How can i help
/// you today?" greeting. [onSuggestionTap] is kept for call-site stability;
/// the redesign has no starter chips (prompts live in the tools sheet).
class EmptyChatSuggestions extends StatelessWidget {
  const EmptyChatSuggestions({
    super.key,
    required this.onSuggestionTap,
    this.userName = '',
  });

  final ValueChanged<String> onSuggestionTap;

  /// First name for the greeting; empty renders a plain "Hello".
  final String userName;

  @override
  Widget build(BuildContext context) {
    final user = userName;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Orb(size: 74),
            const SizedBox(height: AppSpacing.s26),
            Text(
              user.isEmpty
                  ? context.tr.figHelloNhowCanIHelpNyou
                  : context.tr.figHelloNhowCanIHelpNyou2(user),
              textAlign: TextAlign.center,
              style: Fig.t(
                context,
                size: 36,
                color: Colors.white,
                height: 1.08,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
