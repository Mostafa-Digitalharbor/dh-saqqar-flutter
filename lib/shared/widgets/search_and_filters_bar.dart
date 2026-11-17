import 'package:flutter/material.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_sizes.dart';
import '../extensions/context_extensions.dart';
import 'chip_strip.dart';
import 'filter_pill.dart';
import '../../core/theme/app_radius.dart';

class SearchFilterOption<T> {
  const SearchFilterOption({required this.value, required this.label});

  final T value;
  final String label;
}

class SearchAndFiltersBar<T> extends StatelessWidget {
  const SearchAndFiltersBar({
    super.key,
    required this.controller,
    required this.hintText,
    required this.query,
    required this.onQueryChanged,
    this.filters = const [],
    this.selectedFilter,
    this.onFilterSelected,
  });

  final TextEditingController controller;
  final String hintText;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final List<SearchFilterOption<T>> filters;
  final T? selectedFilter;
  final ValueChanged<T?>? onFilterSelected;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: s.surface2.withValues(
              alpha: context.alpha(AppAlphaPairs.panelStrong),
            ),
            borderRadius: AppRadius.inputR,
            border: Border.all(color: s.cardBorder),
          ),
          child: TextField(
            controller: controller,
            onChanged: onQueryChanged,
            style: context.text.bodyMedium,
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: context.text.bodyMedium?.copyWith(color: s.muted),
              filled: false,
              isCollapsed: false,
              contentPadding: const EdgeInsets.symmetric(
                vertical: AppSpacing.s12,
              ),
              prefixIcon: Icon(
                AppIcons.search,
                size: AppIconSizes.regular,
                color: s.muted,
              ),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: context.tr.clearSearch,
                      icon: Icon(
                        AppIcons.close,
                        size: AppIconSizes.regular,
                        color: s.muted,
                      ),
                      onPressed: () {
                        controller.clear();
                        onQueryChanged('');
                      },
                    ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
        ),
        if (filters.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s10),
          // Sizes to the chips rather than pinning `height: 38`, which
          // clipped Arabic descenders at large text scales with no overflow
          // warning.
          ChipStrip(
            children: [
              for (final filter in filters)
                FilterPill(
                  label: filter.label,
                  selected: filter.value == selectedFilter,
                  onTap: () => onFilterSelected?.call(filter.value),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
