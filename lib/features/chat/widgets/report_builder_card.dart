import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/primary_button.dart';
import '../data/interactive_cards.dart';
import 'interactive_card_shell.dart';
import '../../../core/theme/app_sizes.dart';

/// Loads one page of `GET /api/v1/report-entities/` for [entity], optionally
/// narrowed by [query]. Injected so the card is drivable in a widget test
/// without a Dio stack, and so the screen owns the conversation id.
typedef ReportEntityLoader =
    Future<ReportEntityPage> Function(String entity, String query);

/// §4b — the report configurator card
/// (`tool_payload.kind == report_builder`).
///
/// Chips for type / period / lens / format, plus a record multi-select for
/// the customers / vendors / employees families. The picks compose a precise
/// report request that is sent as an ordinary message.
///
/// Labels come straight from the server's `label` on each chip. The web
/// localizes them through client keys (`rbType_<key>` …) and falls back to
/// the same `label`; mobile renders the server string so a report type the
/// backend adds tomorrow shows up correctly instead of as a raw key.
class ReportBuilderCard extends StatefulWidget {
  const ReportBuilderCard({
    super.key,
    required this.payload,
    required this.onSend,
    this.entityLoader,
  });

  final ReportBuilderPayload payload;
  final ValueChanged<String> onSend;

  /// Null disables the record multi-select entirely (e.g. a chat with no
  /// bound environment, where the endpoint answers 400). The rest of the
  /// card still works — a report without a record filter is a valid report.
  final ReportEntityLoader? entityLoader;

  @override
  State<ReportBuilderCard> createState() => _ReportBuilderCardState();
}

class _ReportBuilderCardState extends State<ReportBuilderCard> {
  ReportOption? _type;
  ReportOption? _period;
  ReportLens? _lens;
  ReportOption? _format;

  /// Ticked records, keyed by id so re-querying with a search term never
  /// drops a selection the user made under a previous query.
  final _selected = <String, ReportEntity>{};

  ReportEntityPage? _entities;
  bool _loadingEntities = false;
  String _entityQuery = '';

  /// The entity family the current picks call for, or null when none does.
  String? get _entityFamily {
    final lensEntity = _lens?.entity ?? '';
    if (ReportBuilderPayload.entityFamilies.contains(lensEntity)) {
      return lensEntity;
    }
    // Fall back to the type key: the doc describes the customers / vendors /
    // employees *families*, and not every deployment tags the lens.
    final typeKey = _type?.key ?? '';
    for (final family in ReportBuilderPayload.entityFamilies) {
      if (typeKey.contains(family)) return family;
    }
    return null;
  }

  Future<void> _loadEntities({String query = ''}) async {
    final loader = widget.entityLoader;
    final family = _entityFamily;
    if (loader == null || family == null) return;
    setState(() {
      _loadingEntities = true;
      _entityQuery = query;
    });
    try {
      final page = await loader(family, query);
      if (!mounted) return;
      setState(() {
        _entities = page;
        _loadingEntities = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingEntities = false);
      // A failed record lookup must not block the report: the user can still
      // build an unfiltered one. Surface the real cause and move on.
      AppToast.show(
        context,
        message: ApiErrorMapper.message(context, e),
        variant: ToastVariant.error,
      );
    }
  }

  /// Re-resolves the record picker after a type / lens change: a different
  /// family means the loaded list and the ticks against it are stale.
  void _onFamilyMayHaveChanged(String? previousFamily) {
    final family = _entityFamily;
    if (family == previousFamily) return;
    _selected.clear();
    _entities = null;
    _entityQuery = '';
    if (family != null) _loadEntities();
  }

  String _composeRequest(BuildContext context) {
    final tr = context.tr;
    final records = _selected.values.map((e) => e.name).join('، ');
    // The lens carries a server-authored submit sentence in both locales.
    // Prefer it: the backend wrote the exact phrasing its own agent parses
    // best, and a client-composed line is only a fallback.
    // Chip text in the request matches what the user saw on the chip, in
    // their language — consistent with `submit_en` / `submit_ar` being
    // per-locale. Falls back to the server label wherever no client key
    // exists, so the agent always receives a term the backend authored.
    final typeLabel = _type?.displayLabel(tr, ReportLabelKeys.type) ?? '';
    final periodLabel = _period?.displayLabel(tr, ReportLabelKeys.period) ?? '';
    final formatLabel = _format?.displayLabel(tr, ReportLabelKeys.format) ?? '';

    final lensSubmit = _lens?.submitFor(arabic: tr.isArabic) ?? '';
    if (lensSubmit.isNotEmpty) {
      final extras = <String>[
        if (_period != null) '${tr.reportPeriod}: $periodLabel',
        if (_format != null) '${tr.reportFormat}: $formatLabel',
        if (records.isNotEmpty) '${tr.reportRecords}: $records',
      ];
      return extras.isEmpty
          ? lensSubmit
          : '$lensSubmit\n${extras.map((e) => '- $e').join('\n')}';
    }
    return tr.reportCompose(
      type: typeLabel,
      period: periodLabel,
      format: formatLabel,
      lens: _lens?.displayLabel(tr),
      records: records,
    );
  }

  void _submit(BuildContext context) {
    if (_type == null) {
      AppToast.show(
        context,
        message: context.tr.reportNeedsType,
        variant: ToastVariant.info,
      );
      return;
    }
    widget.onSend(_composeRequest(context));
  }

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final payload = widget.payload;
    final lenses = payload.lensesFor(_type?.key);

    return InteractiveCardShell(
      icon: AppIcons.fileText,
      title: tr.reportTitle,
      children: [
        _ChipGroup<ReportOption>(
          label: tr.reportType,
          options: payload.types,
          labelOf: (o) => o.displayLabel(tr, ReportLabelKeys.type),
          selected: _type,
          onSelected: (o) => setState(() {
            final before = _entityFamily;
            _type = o;
            // A lens from the previous type's group no longer applies.
            if (o != null && !payload.lensesFor(o.key).contains(_lens)) {
              _lens = null;
            }
            _onFamilyMayHaveChanged(before);
          }),
        ),
        if (payload.periods.isNotEmpty)
          _ChipGroup<ReportOption>(
            label: tr.reportPeriod,
            options: payload.periods,
            labelOf: (o) => o.displayLabel(tr, ReportLabelKeys.period),
            selected: _period,
            onSelected: (o) => setState(() => _period = o),
          ),
        if (lenses.isNotEmpty)
          _ChipGroup<ReportLens>(
            label: tr.reportLens,
            options: lenses,
            labelOf: (o) => o.displayLabel(tr),
            selected: _lens,
            onSelected: (o) => setState(() {
              final before = _entityFamily;
              _lens = o;
              _onFamilyMayHaveChanged(before);
            }),
          ),
        if (payload.formats.isNotEmpty)
          _ChipGroup<ReportOption>(
            label: tr.reportFormat,
            options: payload.formats,
            labelOf: (o) => o.displayLabel(tr, ReportLabelKeys.format),
            selected: _format,
            onSelected: (o) => setState(() => _format = o),
          ),
        if (_entityFamily != null && widget.entityLoader != null)
          _EntityPicker(
            page: _entities,
            loading: _loadingEntities,
            query: _entityQuery,
            selected: _selected,
            onSearch: (q) => _loadEntities(query: q),
            onToggle: (entity) => setState(() {
              if (_selected.remove(entity.id) == null) {
                _selected[entity.id] = entity;
              }
            }),
          ),
        const SizedBox(height: AppSpacing.s14),
        PrimaryButton(
          label: tr.reportBuild,
          icon: AppIcons.send,
          expand: true,
          onPressed: _type == null ? null : () => _submit(context),
        ),
      ],
    );
  }
}

/// One labelled row of single-select chips. Tapping the selected chip again
/// clears it — a period the user picked by accident shouldn't be permanent.
class _ChipGroup<T extends Object> extends StatelessWidget {
  const _ChipGroup({
    required this.label,
    required this.options,
    required this.labelOf,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final List<T> options;
  final String Function(T) labelOf;
  final T? selected;
  final ValueChanged<T?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardFieldLabel(label),
          Wrap(
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s8,
            children: [
              for (final option in options)
                CardChoiceChip(
                  label: labelOf(option),
                  selected: option == selected,
                  onTap: () => onSelected(option == selected ? null : option),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The secondary record multi-select — "which customers / vendors /
/// employees?" — backed by `GET /api/v1/report-entities/`.
class _EntityPicker extends StatelessWidget {
  const _EntityPicker({
    required this.page,
    required this.loading,
    required this.query,
    required this.selected,
    required this.onSearch,
    required this.onToggle,
  });

  final ReportEntityPage? page;
  final bool loading;
  final String query;
  final Map<String, ReportEntity> selected;
  final ValueChanged<String> onSearch;
  final ValueChanged<ReportEntity> onToggle;

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final s = context.saqqar;
    final items = page?.items ?? const <ReportEntity>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: CardFieldLabel(tr.reportPickRecords)),
            if (selected.isNotEmpty)
              Text(
                tr.reportSelectedCount(selected.length),
                style: context.text.labelSmall?.copyWith(color: s.brandCyan),
              ),
          ],
        ),
        AppTextField(
          hint: tr.reportSearchRecords,
          initialValue: query,
          prefixIcon: AppIcons.search,
          textInputAction: TextInputAction.search,
          onSubmitted: onSearch,
        ),
        const SizedBox(height: AppSpacing.s8),
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.s12),
            child: Center(
              child: SizedBox(
                width: AppControlSizes.spinnerSmall,
                height: AppControlSizes.spinnerSmall,
                child: CircularProgressIndicator(
                  strokeWidth: AppStrokeWidths.spinnerThin,
                ),
              ),
            ),
          )
        else if (page != null && items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
            child: Text(
              tr.reportNoRecords,
              style: context.text.bodySmall?.copyWith(color: s.muted),
            ),
          )
        else
          // Capped height so a 1,000-row list can't swallow the chat. The
          // list scrolls inside the card; the card keeps its own size.
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: AppSheetHeights.reportRecordsMax,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: items.length,
              itemBuilder: (context, i) {
                final entity = items[i];
                return Material(
                  type: MaterialType.transparency,
                  child: CheckboxListTile(
                    value: selected.containsKey(entity.id),
                    onChanged: (_) => onToggle(entity),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(
                      entity.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodyMedium,
                    ),
                  ),
                );
              },
            ),
          ),
        // `truncated` is the server saying "there are more than these" — show
        // it, rather than letting the user believe a capped list is the whole
        // set and quietly build a report over the wrong records.
        if (page?.truncated ?? false)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.s4),
            child: Text(
              tr.reportRecordsTruncated(items.length),
              style: context.text.labelSmall?.copyWith(
                color: s.warning,
                height: AppLineHeights.compact,
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.s4),
      ],
    );
  }
}
