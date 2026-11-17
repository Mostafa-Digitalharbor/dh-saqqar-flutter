import 'package:flutter/material.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_sizes.dart';
import '../extensions/context_extensions.dart';

/// The small search input that sits inside a drawer or a sheet.
///
/// Distinct from [SearchAndFiltersBar], which is the screen-level bar with
/// filter chips: this one is one row tall, uses the tighter button radius and
/// the smaller type, and carries no filters. Both exist on purpose.
///
/// It replaced two private copies — one in the chat sidebar, one in the vault
/// project sheet — that were identical apart from their hint and the fact
/// that only one of them offered a way to clear the query. Unifying them
/// settles that: clearing is available in both, because a search box you can
/// type into and not empty is a small trap either way.
class CompactSearchField extends StatelessWidget {
  const CompactSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    this.textInputAction,
  });

  final TextEditingController controller;

  /// What is being searched — conversations, environments. Passed in rather
  /// than resolved here so this widget knows nothing about its callers.
  final String hintText;

  final ValueChanged<String> onChanged;

  /// `TextInputAction.search` where the keyboard's action key should say so.
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: s.surface2.withValues(alpha: context.alpha(AppAlphaPairs.panel)),
        borderRadius: AppRadius.buttonR,
        border: Border.all(color: s.cardBorder),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: textInputAction,
        style: context.text.bodySmall,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: context.text.bodySmall?.copyWith(color: s.muted),
          prefixIcon: Icon(
            AppIcons.search,
            size: AppIconSizes.small,
            color: s.muted,
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: AppControlSizes.rowMin,
            minHeight: AppControlSizes.rowMin,
          ),
          // Appears only once there is something to clear, so an empty field
          // stays a plain box rather than showing a button that does nothing.
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: Icon(
                    AppIcons.close,
                    size: AppIconSizes.compact,
                    color: s.muted,
                  ),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                  visualDensity: VisualDensity.compact,
                  tooltip: context.tr.clearSearch,
                ),
          isCollapsed: true,
          contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.s10),
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }
}
