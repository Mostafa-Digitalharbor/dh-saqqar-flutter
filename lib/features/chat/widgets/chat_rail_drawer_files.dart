part of 'chat_rail_drawer.dart';

class _FilesTab extends StatelessWidget {
  const _FilesTab({
    required this.artifacts,
    required this.search,
    required this.filter,
    required this.onFilter,
    required this.onSearch,
    required this.onOpen,
    required this.onDetails,
  });

  final List<inbox_api.Artifact> artifacts;
  final TextEditingController search;
  final int filter;
  final ValueChanged<int> onFilter;
  final VoidCallback onSearch;
  final void Function(inbox_api.Artifact) onOpen;
  final void Function(inbox_api.Artifact) onDetails;

  static bool _matches(int f, inbox_api.Artifact a) {
    final n = a.name.toLowerCase();
    switch (f) {
      case 1:
        return n.endsWith('.doc') ||
            n.endsWith('.docx') ||
            n.endsWith('.txt') ||
            n.endsWith('.md');
      case 2:
        return FileKinds.isImage(n);
      case 3:
        return n.endsWith('.pdf');
      case 4:
        return n.endsWith('.xls') || n.endsWith('.xlsx') || n.endsWith('.csv');
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final labels = [
      context.tr.figAll,
      context.tr.figDocuments,
      context.tr.figImages,
      context.tr.figPdfs,
      context.tr.figSpreadsheets,
    ];
    final q = search.text.trim().toLowerCase();
    final shown = artifacts
        .where(
          (a) =>
              _matches(filter, a) &&
              (q.isEmpty || a.name.toLowerCase().contains(q)),
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Fig.hairline),
          ),
          child: Row(
            children: [
              const Icon(LucideIcons.search, size: 17, color: Fig.muted),
              const SizedBox(width: AppSpacing.s10),
              Expanded(
                child: TextField(
                  controller: search,
                  onChanged: (_) => onSearch(),
                  style: Fig.t(context, size: 13, color: Fig.navy),
                  decoration: InputDecoration(
                    hintText: context.tr.figSearchSharedFiles,
                    hintStyle: Fig.t(context, size: 13, color: Fig.muted),
                    isCollapsed: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        SizedBox(
          height: 30,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: labels.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.s6),
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => onFilter(i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: i == filter ? Fig.tintBlue : Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: i == filter ? Colors.transparent : Fig.hairline,
                  ),
                ),
                child: Text(
                  labels[i],
                  style: Fig.t(
                    context,
                    size: 12.5,
                    weight: i == filter ? FontWeight.w600 : FontWeight.w400,
                    color: i == filter ? Fig.blue : Fig.muted,
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 18, 0, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  context.tr.figSharedFiles,
                  style: Fig.t(context, size: 13, color: Fig.muted),
                ),
              ),
              Flexible(
                child: Text(
                  context.tr.figFiles2(shown.length),
                  style: Fig.t(context, size: 13, color: Fig.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                context.tr.noExportsTitle,
                style: Fig.t(context, size: 14, color: Fig.muted),
              ),
            ),
          ),
        for (var i = 0; i < shown.length; i++)
          _FileRow(
            artifact: shown[i],
            last: i == shown.length - 1,
            onOpen: () => onOpen(shown[i]),
            onDetails: () => onDetails(shown[i]),
          ),
      ],
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.artifact,
    required this.last,
    required this.onOpen,
    required this.onDetails,
  });

  final inbox_api.Artifact artifact;
  final bool last;
  final VoidCallback onOpen;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final a = artifact;
    final (icon, color) = _fileGlyph(a.name);
    final bytes = a.sizeBytes;
    final created = a.createdAt;
    final meta = [
      if (bytes != null) humanBytes(bytes, context.tr),
      if (created != null)
        '${AppDateFormat.date(context, created)}, ${AppDateFormat.time(context, created)}',
    ].join(' · ');
    return GestureDetector(
      onLongPress: onDetails,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s14),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: Fig.dividerCool)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.s2),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Fig.t(
                      context,
                      size: 14,
                      weight: FontWeight.w600,
                      color: Fig.navy,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Fig.t(context, size: 12, color: Fig.muted),
                  ),
                  if ((a.conversation?.title ?? '').isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.s8),
                    Text(
                      a.conversation!.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Fig.t(context, size: 12.5, color: Fig.navy),
                    ),
                  ],
                ],
              ),
            ),
            GestureDetector(
              onTap: onOpen,
              child: const Padding(
                padding: EdgeInsets.fromLTRB(8, 24, 4, 0),
                child: Icon(LucideIcons.eye, size: 20, color: Fig.blue),
              ),
            ),
            GestureDetector(
              onTap: onOpen,
              child: const Padding(
                padding: EdgeInsets.fromLTRB(8, 24, 0, 0),
                child: Icon(LucideIcons.download, size: 20, color: Fig.blue),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
