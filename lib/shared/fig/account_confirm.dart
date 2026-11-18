import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../features/auth/view_model/auth_cubit.dart';
import 'fig.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_sizes.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/fig_metrics.dart';
import '../../core/theme/app_colors.dart';

/// The notched confirmation sheet used for "Sign out of Saqqar?" and "Delete
/// your account?". Shows the signed-in user, a red primary action and Cancel;
/// [requireText] adds the "Type DELETE to confirm" gate.
Future<bool> showFigAccountConfirm(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  String? requireText,
}) async {
  final ok = await showFigSheet<bool>(
    context,
    builder: (_) => _AccountConfirm(
      title: title,
      body: body,
      confirmLabel: confirmLabel,
      requireText: requireText,
    ),
  );
  return ok ?? false;
}

class _AccountConfirm extends StatefulWidget {
  const _AccountConfirm({
    required this.title,
    required this.body,
    required this.confirmLabel,
    this.requireText,
  });

  final String title;
  final String body;
  final String confirmLabel;
  final String? requireText;

  @override
  State<_AccountConfirm> createState() => _AccountConfirmState();
}

class _AccountConfirmState extends State<_AccountConfirm> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  bool get _armed =>
      widget.requireText == null ||
      _text.text.trim().toUpperCase() == widget.requireText!.toUpperCase();

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthCubit>().state.user;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FigNotchSheet(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.s22, 0, AppSpacing.s22, AppSpacing.s26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: Fig.t(
                  context,
                  size: FigMetrics.fontFig23,
                  weight: FontWeight.w600,
                  color: Fig.navy,
                ),
              ),
              const SizedBox(height: AppSpacing.s12),
              Text(
                widget.body,
                textAlign: TextAlign.center,
                style: Fig.t(
                  context,
                  size: AppFontSizes.caption,
                  color: Fig.mutedBlue,
                  height: AppLineHeights.compact,
                ),
              ),
              const SizedBox(height: AppSpacing.s22),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s18,
                  vertical: AppSpacing.s14,
                ),
                decoration: BoxDecoration(
                  color: AppColors.figCFFE6E7EC,
                  borderRadius: BorderRadius.circular(AppRadius.heroPlate),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.user, size: AppIconSizes.action, color: Fig.muted),
                    const SizedBox(width: AppSpacing.s14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.displayName ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Fig.t(
                              context,
                              size: FigMetrics.fontFig11,
                              weight: FontWeight.w700,
                              color: Fig.navy,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s2),
                          Text(
                            user?.email ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Fig.t(context, size: FigMetrics.fontFig10, color: Fig.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.requireText != null) ...[
                const SizedBox(height: AppSpacing.s18),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    context.tr.figTypeToConfirm(widget.requireText),
                    style: Fig.t(context, size: FigMetrics.fontFig11, color: Fig.navy),
                  ),
                ),
                const SizedBox(height: AppSpacing.s8),
                Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s18,
                  ),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: AppColors.figCFFF7F8FC,
                    borderRadius: BorderRadius.circular(FigMetrics.radFig25),
                    border: Border.all(color: AppColors.figCFF4E6AEA),
                  ),
                  child: TextField(
                    controller: _text,
                    onChanged: (_) => setState(() {}),
                    style: Fig.t(context, size: AppFontSizes.caption, color: Fig.navy),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      isCollapsed: true,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.s22),
              FigButton(
                label: widget.confirmLabel,
                danger: true,
                height: 46,
                fontSize: AppFontSizes.dense,
                weight: FontWeight.w600,
                onPressed: _armed ? () => Navigator.pop(context, true) : null,
              ),
              const SizedBox(height: AppSpacing.s10),
              FigButton(
                label: context.tr.figCancel,
                secondary: true,
                height: 46,
                fontSize: AppFontSizes.dense,
                onPressed: () => Navigator.pop(context, false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
