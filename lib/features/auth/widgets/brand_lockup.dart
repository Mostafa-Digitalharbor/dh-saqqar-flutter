import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/saqqar_logo.dart';

/// Centered/left-aligned Saqqar wordmark + tagline used on the auth
/// screens (`compact: true` on phones, otherwise the wider hero layout).
///
/// Renders the full "SAQQÂR" wordmark image (via [SaqqarLogo]) instead
/// of the circular icon-in-a-ring — the user asked for the full name
/// to be visible up top on sign-in/sign-up. The separate "Saqqar" text
/// label is gone because the wordmark already shows the name.
class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final logoHeight = compact ? 56.0 : 72.0;

    return Column(
      crossAxisAlignment: compact
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        SaqqarLogo(height: logoHeight),
        SizedBox(height: compact ? 12 : 18),
        Text(
          context.tr.appTagline,
          textAlign: compact ? TextAlign.center : TextAlign.start,
          style: context.text.bodyMedium?.copyWith(
            color: s.muted,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
