import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../features/auth/view_model/auth_cubit.dart';
import 'fig.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_sizes.dart';

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
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: Fig.t(
                  context,
                  size: 23,
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
                  size: 13,
                  color: Fig.mutedBlue,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSpacing.s22),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6E7EC),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.user, size: 20, color: Fig.muted),
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
                              size: 11,
                              weight: FontWeight.w700,
                              color: Fig.navy,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s2),
                          Text(
                            user?.email ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Fig.t(context, size: 10, color: Fig.muted),
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
                    style: Fig.t(context, size: 11, color: Fig.navy),
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
                    color: const Color(0xFFF7F8FC),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: const Color(0xFF4E6AEA)),
                  ),
                  child: TextField(
                    controller: _text,
                    onChanged: (_) => setState(() {}),
                    style: Fig.t(context, size: 13, color: Fig.navy),
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
                fontSize: 14,
                weight: FontWeight.w600,
                onPressed: _armed ? () => Navigator.pop(context, true) : null,
              ),
              const SizedBox(height: AppSpacing.s10),
              FigButton(
                label: context.tr.figCancel,
                secondary: true,
                height: 46,
                fontSize: 14,
                onPressed: () => Navigator.pop(context, false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
