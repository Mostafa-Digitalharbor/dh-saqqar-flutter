import 'package:flutter/material.dart';
import '../../shared/fig/fig.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_sizes.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/fig_metrics.dart';
import '../../core/theme/app_colors.dart';

enum EnvMode { live, readOnly, autoApprove }

/// Three radio cards: Live / Read only / Auto approve.
class EnvTypePicker extends StatelessWidget {
  const EnvTypePicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.dark = false,
  });

  final EnvMode value;
  final ValueChanged<EnvMode> onChanged;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final items = [
      (EnvMode.live, context.tr.figLive, context.tr.figReadWrite),
      (EnvMode.readOnly, context.tr.figReadOnly, context.tr.figNoChanges),
      (
        EnvMode.autoApprove,
        context.tr.figAutoApprove,
        context.tr.figTrustedActions,
      ),
    ];
    final lastIndex = items.length - items.length.sign;
    // The height follows the content (two 1.5-line-height text lines and the
    // gap): a fixed `scale(78)` was 0.1px short at 1.25x text and overflowed.
    // 78 scaled stays as the floor so the three cards still match each other.
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: MediaQuery.textScalerOf(context).scale(78),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, it) in items.indexed)
              Expanded(
                child: Padding(
                  padding: EdgeInsetsDirectional.only(
                    end: i == lastIndex ? AppSpacing.zero : AppSpacing.s6,
                  ),
                  child: GestureDetector(
                    onTap: () => onChanged(it.$1),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.s10,
                        AppSpacing.s10,
                        AppSpacing.s6,
                        AppSpacing.s10,
                      ),
                      decoration: BoxDecoration(
                        color: dark
                            ? AppColors.figWhite.withValues(
                                alpha: AppAlphas.a04,
                              )
                            : AppColors.figWhite.withValues(
                                alpha: AppAlphas.a40,
                              ),
                        borderRadius: BorderRadius.circular(AppRadius.bubble),
                        border: Border.all(
                          color: value == it.$1
                              ? (dark ? Fig.blueSoft : AppColors.figCFF5878E8)
                              : (dark
                                    ? AppColors.figWhite.withValues(
                                        alpha: AppAlphas.a12,
                                      )
                                    : AppColors.figCFFD6DCF3),
                          width: value == it.$1 ? 1.4 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: AlignmentDirectional.centerStart,
                                  child: Text(
                                    it.$2,
                                    maxLines: 1,
                                    style: Fig.t(
                                      context,
                                      size: AppFontSizes.microCaps,
                                      color: dark
                                          ? AppColors.figWhite.withValues(
                                              alpha: AppAlphas.a80,
                                            )
                                          : Fig.muted,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.s2),
                              _Radio(selected: value == it.$1, dark: dark),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.s6),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              it.$3,
                              maxLines: 1,
                              style: Fig.t(
                                context,
                                size: FigMetrics.fontFig11,
                                color: dark
                                    ? AppColors.figWhite
                                    : Fig.mutedSoft,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.selected, required this.dark});

  final bool selected;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: FigMetrics.size16,
      height: FigMetrics.size16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? Fig.blueFocus : (dark ? Colors.white30 : Fig.muted),
          width: FigMetrics.bwFig1U2,
        ),
      ),
      child: selected
          ? Center(
              child: Container(
                width: FigMetrics.size8,
                height: FigMetrics.size8,
                decoration: const BoxDecoration(
                  color: Fig.blueFocus,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
    );
  }
}

/// "Odoo connection | API key" underline tabs.
class ConnectionTabs extends StatelessWidget {
  const ConnectionTabs({
    super.key,
    required this.apiKey,
    required this.onChanged,
    this.dark = false,
  });

  final bool apiKey;
  final ValueChanged<bool> onChanged;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    Widget tab(IconData? icon, String label, bool active, VoidCallback tap) {
      final c = active
          ? (dark ? AppColors.figWhite : Fig.navy)
          : (dark ? Colors.white54 : Fig.mutedSoft);
      return GestureDetector(
        onTap: tap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s8,
            AppSpacing.s4,
            AppSpacing.s12,
            AppSpacing.s8,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? Fig.blueStrong : Colors.transparent,
                width: AppBorderWidths.ring,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: AppIconSizes.compact, color: c),
                const SizedBox(width: AppSpacing.s6),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Fig.t(context, size: FigMetrics.fontFig10, color: c),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: dark ? Colors.white12 : AppColors.figCFFD9DEEE,
          ),
        ),
      ),
      child: Row(
        children: [
          Flexible(
            child: tab(
              AppIcons.database,
              context.tr.figOdooConnection,
              !apiKey,
              () => onChanged(false),
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          Flexible(
            child: tab(
              null,
              context.tr.figLabelApiKey,
              apiKey,
              () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pill-shaped select (Authentication / Execution time / …).
class FigDropdown extends StatelessWidget {
  const FigDropdown({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.dark = false,
    this.height = 54,
    this.filled = false,
    this.labelOf,
  });

  final String value;
  final List<String> options;

  /// Display text for an option; the stored/returned value stays [options]'s
  /// own string, so persisted data is unaffected by translation.
  final String Function(String)? labelOf;
  final ValueChanged<String> onChanged;
  final bool dark;
  final double height;

  /// Solid light fill (dialog fields) instead of the glass pill.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onChanged,
      position: PopupMenuPosition.under,
      itemBuilder: (_) => [
        for (final o in options)
          PopupMenuItem(value: o, child: Text(labelOf?.call(o) ?? o)),
      ],
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
        decoration: BoxDecoration(
          color: filled
              ? Fig.panelTint
              : (dark
                    ? AppColors.figWhite.withValues(alpha: AppAlphas.a05)
                    : AppColors.figWhite.withValues(alpha: AppAlphas.a34)),
          borderRadius: BorderRadius.circular(height / 2),
          border: Border.all(
            color: filled
                ? Fig.panelBorder
                : (dark ? Colors.white12 : Fig.fieldBorder),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                labelOf?.call(value) ?? value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Fig.t(
                  context,
                  size: AppFontSizes.caption,
                  color: dark ? AppColors.figWhite : Fig.muted,
                ),
              ),
            ),
            Icon(
              AppIcons.chevronDown,
              size: AppIconSizes.action,
              color: dark ? AppColors.figWhite : Fig.tileText,
            ),
          ],
        ),
      ),
    );
  }
}
