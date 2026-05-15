import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/status_pill.dart';
import 'brand_lockup.dart';

/// Left-hand brand panel shown on wide (≥900 px) auth viewports. Contains
/// the lockup, hero copy, four product status pills, and a CTA into the
/// workspace.
class BrandPanel extends StatelessWidget {
  const BrandPanel({super.key, required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;

    return Container(
      padding: const EdgeInsets.all(56),
      decoration: BoxDecoration(
        color: s.surface3,
        border: Border(right: BorderSide(color: s.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          const BrandLockup(),
          const SizedBox(height: 18),
          Text(
            context.tr.authBrandTitle,
            style: context.text.displaySmall?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.08,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.tr.authBrandBody,
            style: context.text.bodyLarge?.copyWith(
              color: s.muted,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusPill(label: context.tr.smartDiagnosis),
              StatusPill(label: context.tr.liveTools),
              StatusPill(label: context.tr.approvalGated),
              StatusPill(label: context.tr.perUserVault),
            ],
          ),
          const SizedBox(height: 32),
          PrimaryButton(
            label: context.tr.openWorkspace,
            icon: AppIcons.chevronRight,
            onPressed: onStart,
          ),
          const Spacer(),
          Text(
            context.tr.poweredByDigitalHarbor,
            style: context.text.labelSmall?.copyWith(color: s.muted),
          ),
        ],
      ),
    );
  }
}
