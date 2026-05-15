import 'package:flutter/material.dart';

import '../../../core/theme/app_icons.dart';
import '../../../shared/extensions/context_extensions.dart';

/// Tappable pill above the composer showing the active credential. Tap opens
/// the credential picker sheet.
class CredentialChip extends StatelessWidget {
  const CredentialChip({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: s.brandCyan.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: s.brandCyan.withValues(alpha: 0.26)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(AppIcons.key, size: 13, color: s.brandCyan),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelMedium?.copyWith(
                    color: s.brandCyan,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(AppIcons.chevronDown, size: 13, color: s.brandCyan),
            ],
          ),
        ),
      ),
    );
  }
}
