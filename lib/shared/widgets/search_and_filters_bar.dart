import 'package:flutter/material.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_icons.dart';
import '../extensions/context_extensions.dart';

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
            color: s.surface2.withValues(alpha: context.isDark ? 0.62 : 0.86),
            borderRadius: BorderRadius.circular(14),
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
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              prefixIcon: Icon(AppIcons.search, size: 18, color: s.muted),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: context.tr.clearSearch,
                      icon: Icon(AppIcons.close, size: 18, color: s.muted),
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
          const SizedBox(height: 10),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              itemBuilder: (context, index) {
                final filter = filters[index];
                final isSelected = filter.value == selectedFilter;
                return _FilterChip(
                  label: filter.label,
                  selected: isSelected,
                  onTap: () => onFilterSelected?.call(filter.value),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemCount: filters.length,
            ),
          ),
        ],
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? s.brandCyan.withValues(alpha: context.isDark ? 0.16 : 0.12)
                : s.surface2.withValues(alpha: context.isDark ? 0.55 : 0.86),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? s.brandCyan.withValues(alpha: 0.4)
                  : s.cardBorder,
            ),
          ),
          child: Text(
            label,
            style: context.text.labelMedium?.copyWith(
              color: selected ? s.brandCyan : s.text,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
