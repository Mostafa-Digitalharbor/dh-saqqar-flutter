import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/app_icon_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/credential_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../../../shared/widgets/feature_intro_card.dart';
import '../../../shared/widgets/ghost_button.dart';
import '../../../shared/widgets/mini_chip.dart';
import '../../../shared/widgets/page_scaffold.dart';
import '../../../shared/widgets/pagination_bar.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/search_and_filters_bar.dart';
import '../../../shared/widgets/status_pill.dart';
import '../../demo/saqqar_demo_data.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  static const _pageSize = 30;

  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  late final List<DemoCredential> _credentials = List.of(demoCredentials);

  String _query = '';
  DemoCredentialKind? _filter;
  int _pageIndex = 0;

  List<DemoCredential> get _filtered {
    final q = _query.trim().toLowerCase();
    return _credentials.where((item) {
      final kindMatches = _filter == null || item.kind == _filter;
      final queryMatches =
          q.isEmpty ||
          item.name.toLowerCase().contains(q) ||
          item.label.toLowerCase().contains(q) ||
          item.source.toLowerCase().contains(q);
      return kindMatches && queryMatches;
    }).toList();
  }

  List<DemoCredential> get _paged {
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
    final allCredentials = _filtered;
    final visible = _paged;

    return PageScaffold(
      title: context.tr.tabVault,
      controller: _scrollController,
      onRefresh: () async {
        final message = context.tr.credentialsRefreshed;
        await Future<void>.delayed(const Duration(milliseconds: 700));
        if (!context.mounted) return;
        AppToast.show(context, message: message);
      },
      actions: [
        AppIconButton(
          icon: AppIcons.refresh,
          tooltip: context.tr.refreshCredentials,
          bordered: false,
          onPressed: () => _toast(context.tr.credentialsRefreshed),
        ),
        const SizedBox(width: 6),
      ],
      children: [
        FeatureIntroCard(
          title: context.tr.credentialVault,
          body: context.tr.vaultSummaryBody,
          pills: [
            StatusPill(label: context.tr.perUserEncryptedVault, pulsing: true),
          ],
          action: PrimaryButton(
            label: context.tr.addCredential,
            icon: AppIcons.plus,
            expand: true,
            onPressed: _openAddCredential,
          ),
        ),
        const SizedBox(height: 14),
        SearchAndFiltersBar<DemoCredentialKind?>(
          controller: _searchController,
          hintText: context.tr.search,
          query: _query,
          onQueryChanged: (value) => setState(() {
            _query = value;
            _resetPagination();
          }),
          selectedFilter: _filter,
          filters: [
            SearchFilterOption(value: null, label: context.tr.all),
            for (final schema in demoCredentialSchemas)
              SearchFilterOption(value: schema.kind, label: schema.label),
          ],
          onFilterSelected: (kind) => setState(() {
            _filter = kind;
            _resetPagination();
          }),
        ),
        const SizedBox(height: 10),
        if (allCredentials.length > _pageSize) ...[
          PaginationBar(
            page: _pageIndex + 1,
            pageCount: _pageCount,
            visibleCount: visible.length,
            totalCount: allCredentials.length,
            itemLabel: context.tr.credentials,
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
          child: allCredentials.isEmpty
              ? EmptyState(
                  key: const ValueKey('empty-credentials'),
                  icon: AppIcons.key,
                  title: context.tr.noCredentials,
                  body: context.tr.noCredentialsHint,
                )
              : Column(
                  key: ValueKey('credentials-list-$_filter-${visible.length}'),
                  children: [
                    for (final entry in visible.asMap().entries) ...[
                      FadeSlideIn(
                        key: ValueKey(entry.value.name),
                        index: entry.key,
                        child: _CredentialCard(
                          credential: entry.value,
                          onEdit: () => _openEditCredential(entry.value),
                          onDelete: () => setState(() {
                            _credentials.remove(entry.value);
                            _resetPagination();
                          }),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  void _openAddCredential() {
    final savedMessage = context.tr.credentialSavedApproval;
    showModalBottomSheet<DemoCredential>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _CredentialSheet(),
    ).then((value) {
      if (value == null) return;
      setState(() {
        _credentials.insert(0, value);
        _resetPagination();
      });
      _toast(savedMessage);
    });
  }

  void _openEditCredential(DemoCredential credential) {
    final updatedMessage = context.tr.credentialUpdated;
    showModalBottomSheet<DemoCredential>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _CredentialSheet(existing: credential),
    ).then((value) {
      if (value == null) return;
      setState(() {
        final index = _credentials.indexOf(credential);
        if (index != -1) _credentials[index] = value;
      });
      _toast(updatedMessage);
    });
  }

  void _toast(String text) {
    AppToast.show(context, message: text);
  }
}

enum _CredentialAction { edit, delete }

Color _kindAccent(BuildContext context, DemoCredentialKind kind) {
  final s = context.saqqar;
  return switch (kind) {
    DemoCredentialKind.xmlrpc => s.brandCyan,
    DemoCredentialKind.postgres => s.brandPurple,
    DemoCredentialKind.serverShell => s.warning,
    DemoCredentialKind.github => s.success,
  };
}

class _CredentialCard extends StatelessWidget {
  const _CredentialCard({
    required this.credential,
    required this.onEdit,
    required this.onDelete,
  });

  final DemoCredential credential;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final kindLabel = demoCredentialKindLabel(credential.kind);

    return CredentialCard(
      title: credential.label,
      subtitle: context.tr.credentialSubtitle(credential.name, kindLabel),
      icon: demoCredentialKindIcon(credential.kind),
      accent: _kindAccent(context, credential.kind),
      chips: [
        MiniChip(
          credential.isMemorized ? context.tr.memorized : context.tr.session,
          color: credential.isMemorized
              ? context.saqqar.success
              : context.saqqar.muted,
        ),
        MiniChip(
          credential.lastVerified == null
              ? context.tr.notVerified
              : context.tr.verified(credential.lastVerified!),
          color: credential.lastVerified == null
              ? context.saqqar.muted
              : context.saqqar.brandCyan,
        ),
      ],
      trailing: PopupMenuButton<_CredentialAction>(
        tooltip: context.tr.credentialActions,
        onSelected: (value) {
          if (value == _CredentialAction.edit) onEdit();
          if (value == _CredentialAction.delete) onDelete();
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: _CredentialAction.edit,
            child: _MenuItem(icon: AppIcons.edit, label: context.tr.edit),
          ),
          PopupMenuItem(
            value: _CredentialAction.delete,
            child: _MenuItem(icon: AppIcons.trash, label: context.tr.delete),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [Icon(icon, size: 18), const SizedBox(width: 10), Text(label)],
    );
  }
}

class _CredentialSheet extends StatefulWidget {
  const _CredentialSheet({this.existing});

  final DemoCredential? existing;

  @override
  State<_CredentialSheet> createState() => _CredentialSheetState();
}

class _CredentialSheetState extends State<_CredentialSheet> {
  late DemoCredentialKind _kind =
      widget.existing?.kind ?? DemoCredentialKind.xmlrpc;
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _label = TextEditingController(text: widget.existing?.label ?? '');
  bool _remember = false;

  DemoCredentialSchema get _schema {
    return demoCredentialSchemas.firstWhere((schema) => schema.kind == _kind);
  }

  @override
  void dispose() {
    _name.dispose();
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final schema = _schema;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          top: 0,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 2),
            Container(
              height: 3,
              decoration: const BoxDecoration(
                gradient: AppGradients.primaryCta,
                borderRadius: BorderRadius.all(Radius.circular(999)),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              widget.existing == null
                  ? context.tr.addCredential
                  : context.tr.editCredential,
              style: context.text.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              context.tr.credentialSheetBody,
              style: context.text.bodyMedium?.copyWith(color: s.muted),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<DemoCredentialKind>(
              initialValue: _kind,
              decoration: InputDecoration(labelText: context.tr.kind),
              items: [
                for (final item in demoCredentialSchemas)
                  DropdownMenuItem(value: item.kind, child: Text(item.label)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _kind = value);
              },
            ),
            const SizedBox(height: 12),
            AppTextField(label: context.tr.bundleName, controller: _name),
            const SizedBox(height: 12),
            AppTextField(
              label: context.tr.label,
              controller: _label,
              hint: schema.label,
            ),
            const SizedBox(height: 16),
            for (final field in schema.fields) ...[
              field.options.isEmpty
                  ? field.obscure
                        ? AppPasswordField(label: field.label, hint: field.hint)
                        : AppTextField(
                            label: field.label,
                            hint: field.hint,
                            maxLines: field.multiline ? 4 : 1,
                          )
                  : DropdownButtonFormField<String>(
                      decoration: InputDecoration(labelText: field.label),
                      initialValue: field.options.first,
                      items: [
                        for (final option in field.options)
                          DropdownMenuItem(value: option, child: Text(option)),
                      ],
                      onChanged: (_) {},
                    ),
              const SizedBox(height: 12),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.tr.memorizeCredential),
              value: _remember,
              onChanged: (value) => setState(() => _remember = value),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: GhostButton(
                    label: context.tr.cancel,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PrimaryButton(
                    label: widget.existing == null
                        ? context.tr.saveCredential
                        : context.tr.updateCredential,
                    icon: AppIcons.save,
                    onPressed: _save,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    final fallback = _label.text.trim().isEmpty
        ? demoCredentialKindLabel(_kind)
        : _label.text.trim();
    final generatedName = fallback.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]+'),
      '-',
    );
    Navigator.of(context).pop(
      DemoCredential(
        name: _name.text.trim().isEmpty ? generatedName : _name.text.trim(),
        label: fallback,
        kind: _kind,
        source: _remember ? context.tr.approvalPending : context.tr.session,
        lastVerified: null,
        isMemorized: _remember,
      ),
    );
  }
}
