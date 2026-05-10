import 'package:flutter/material.dart';

import '../../../core/constants/ui_strings.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../../../shared/widgets/feature_intro_card.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/mini_chip.dart';
import '../../../shared/widgets/page_scaffold.dart';
import '../../../shared/widgets/pagination_bar.dart';
import '../../../shared/widgets/search_and_filters_bar.dart';
import '../../../shared/widgets/status_pill.dart';
import '../../demo/saqqar_demo_data.dart';

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  static const _pageSize = 30;

  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  String _query = '';
  String? _kind;
  int _pageIndex = 0;

  List<DemoArtifact> get _filtered {
    final q = _query.trim().toLowerCase();
    return demoArtifacts.where((artifact) {
      final kindMatches = _kind == null || artifact.kind == _kind;
      final queryMatches =
          q.isEmpty ||
          artifact.name.toLowerCase().contains(q) ||
          artifact.conversation.toLowerCase().contains(q);
      return kindMatches && queryMatches;
    }).toList();
  }

  List<DemoArtifact> get _paged {
    final start = _pageIndex * _pageSize;
    return _filtered.skip(start).take(_pageSize).toList();
  }

  int get _pageCount {
    final total = _filtered.length;
    if (total == 0) return 1;
    return ((total - 1) ~/ _pageSize) + 1;
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _filtered.length <= _pageSize) {
      return;
    }
    if (_scrollController.position.extentAfter <= 120 &&
        _pageIndex < _pageCount - 1) {
      _goToPage(_pageIndex + 1);
    }
  }

  void _resetPagination() {
    _pageIndex = 0;
  }

  void _goToPage(int pageIndex) {
    final next = pageIndex.clamp(0, _pageCount - 1);
    if (next == _pageIndex) return;

    setState(() => _pageIndex = next);
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final kinds = demoArtifacts.map((a) => a.kind).toSet();
    final allArtifacts = _filtered;
    final visible = _paged;

    return PageScaffold(
      title: context.tr.tabFiles,
      controller: _scrollController,
      onRefresh: () async {
        await Future<void>.delayed(const Duration(milliseconds: 700));
      },
      children: [
        FeatureIntroCard(
          title: context.tr.artifacts,
          body: context.tr.filesSummaryBody,
          pills: [StatusPill(label: context.tr.downloads, pulsing: true)],
        ),
        const SizedBox(height: 14),
        SearchAndFiltersBar<String?>(
          controller: _searchController,
          hintText: context.tr.searchArtifacts,
          query: _query,
          onQueryChanged: (value) => setState(() {
            _query = value;
            _resetPagination();
          }),
          selectedFilter: _kind,
          filters: [
            SearchFilterOption(value: null, label: context.tr.all),
            for (final kind in kinds)
              SearchFilterOption(value: kind, label: kind),
          ],
          onFilterSelected: (kind) => setState(() {
            _kind = kind;
            _resetPagination();
          }),
        ),
        const SizedBox(height: 12),
        if (allArtifacts.length > _pageSize) ...[
          PaginationBar(
            page: _pageIndex + 1,
            pageCount: _pageCount,
            visibleCount: visible.length,
            totalCount: allArtifacts.length,
            itemLabel: context.tr.artifactsLower,
            onPrevious: _pageIndex == 0
                ? null
                : () => _goToPage(_pageIndex - 1),
            onNext: _pageIndex >= _pageCount - 1
                ? null
                : () => _goToPage(_pageIndex + 1),
          ),
          const SizedBox(height: 10),
        ],
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: allArtifacts.isEmpty
              ? EmptyState(
                  key: const ValueKey('empty-artifacts'),
                  icon: AppIcons.files,
                  title: context.tr.noExportsTitle,
                  body: context.tr.noExportsBody,
                )
              : Column(
                  key: ValueKey(
                    'artifact-list-$_kind-$_query-${visible.length}',
                  ),
                  children: [
                    for (final entry in visible.asMap().entries) ...[
                      FadeSlideIn(
                        key: ValueKey(entry.value.id),
                        index: entry.key,
                        child: _ArtifactCard(artifact: entry.value),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _ArtifactCard extends StatelessWidget {
  const _ArtifactCard({required this.artifact});

  final DemoArtifact artifact;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final accent = _colorFor(context, artifact.kind);
    return GlassCard(
      blur: false,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: accent.withValues(alpha: 0.30)),
            ),
            child: Icon(_iconFor(artifact.kind), color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  artifact.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  artifact.conversation,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall?.copyWith(
                    color: s.muted,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    MiniChip(artifact.kind, color: accent),
                    MiniChip(artifact.size),
                    MiniChip(artifact.createdLabel),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: context.tr.download,
            icon: Icon(AppIcons.download, color: accent),
            onPressed: () => AppToast.show(
              context,
              message: context.tr.downloading(artifact.name),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String kind) {
    return switch (kind) {
      UiStrings.artifactExcel => AppIcons.table,
      UiStrings.artifactCsv => AppIcons.grid,
      UiStrings.artifactLog => AppIcons.fileText,
      UiStrings.artifactImage => AppIcons.image,
      UiStrings.artifactJson => AppIcons.code,
      UiStrings.artifactMarkdown => AppIcons.fileText,
      _ => AppIcons.file,
    };
  }

  Color _colorFor(BuildContext context, String kind) {
    final s = context.saqqar;
    return switch (kind) {
      UiStrings.artifactExcel => s.success,
      UiStrings.artifactCsv => s.success,
      UiStrings.artifactLog => s.warning,
      UiStrings.artifactImage => s.brandPurple,
      UiStrings.artifactJson => s.brandCyan,
      UiStrings.artifactMarkdown => s.brandCyan,
      _ => s.brandCyan,
    };
  }
}
