part of 'chat_rail_drawer.dart';

/// Activity is derived, not fetched: the server has no feed, but every
/// approval raised and every file produced in this chat is already in the
/// snapshot, so the timeline is those events grouped by day, latest first.
class _ActivityTab extends StatelessWidget {
  const _ActivityTab({required this.approvals, required this.artifacts});

  final List<inbox_api.Approval> approvals;
  final List<inbox_api.Artifact> artifacts;

  @override
  Widget build(BuildContext context) {
    final events = <_Event>[];
    for (final a in approvals) {
      final t = a.createdAt;
      if (t == null) continue;
      final adapted = adaptApiApproval(a, context.tr);
      events.add(
        _Event(
          time: t,
          who: a.conversation?.title ?? 'Saqqar',
          text: adapted.title,
          sub: adapted.payload['model'] ?? '',
          tag: switch (a.status) {
            inbox_api.ApprovalStatus.pending => (
              LucideIcons.clock,
              _statusPending,
              context.tr.figPending,
            ),
            inbox_api.ApprovalStatus.approved => (
              LucideIcons.circleCheck,
              _statusApproved,
              context.tr.figApproved,
            ),
            inbox_api.ApprovalStatus.rejected => (
              LucideIcons.circleX,
              _statusRejected,
              context.tr.figRejected,
            ),
          },
        ),
      );
    }
    for (final f in artifacts) {
      final t = f.createdAt;
      if (t == null) continue;
      events.add(
        _Event(
          time: t,
          who: f.conversation?.title ?? 'Saqqar',
          text: f.name,
          sub: f.kind.toUpperCase(),
          tag: (LucideIcons.paperclip, Fig.blue, context.tr.figViewFile),
        ),
      );
    }
    if (events.isEmpty) {
      return _EmptyTab(
        icon: LucideIcons.activity,
        title: context.tr.noServerActivity,
        body: context.tr.serverActivity,
      );
    }
    events.sort((a, b) => b.time.compareTo(a.time));
    final children = <Widget>[
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.s10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                context.tr.figWorkspaceActivity,
                style: Fig.t(context, size: AppFontSizes.caption, color: Fig.muted),
              ),
            ),
            Flexible(
              child: Text(
                context.tr.figLatestFirst,
                style: Fig.t(context, size: AppFontSizes.caption, color: Fig.muted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    ];
    DateTime? day;
    for (final e in events) {
      final d = DateTime(e.time.year, e.time.month, e.time.day);
      if (day != d) {
        day = d;
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(0, AppSpacing.s10, 0, AppSpacing.s8),
            child: Text(
              AppDateFormat.date(context, e.time),
              style: Fig.t(
                context,
                size: AppFontSizes.caption,
                weight: FontWeight.w600,
                color: Fig.navy,
              ),
            ),
          ),
        );
      }
      children.add(_EventRow(event: e));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s16, AppSpacing.s16, AppSpacing.s24),
      children: children,
    );
  }
}

class _Event {
  const _Event({
    required this.time,
    required this.who,
    required this.text,
    required this.sub,
    required this.tag,
  });
  final DateTime time;
  final String who;
  final String text;
  final String sub;
  final (IconData, Color, String) tag;
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});
  final _Event event;

  @override
  Widget build(BuildContext context) {
    final e = event;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(e.who, size: AppIconSizes.tileLarge),
          const SizedBox(width: AppSpacing.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.who,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Fig.t(
                    context,
                    size: AppFontSizes.pillTitle,
                    weight: FontWeight.w600,
                    color: Fig.navy,
                  ),
                ),
                Text(
                  e.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Fig.t(context, size: AppFontSizes.caption, color: Fig.muted),
                ),
                if (e.sub.isNotEmpty)
                  Text(
                    e.sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Fig.t(context, size: AppFontSizes.microCaps, color: Fig.muted),
                  ),
                const SizedBox(height: AppSpacing.s3),
                Row(
                  children: [
                    Icon(e.tag.$1, size: AppIconSizes.dense, color: e.tag.$2),
                    const SizedBox(width: AppSpacing.s4),
                    Flexible(
                      child: Text(
                        e.tag.$3,
                        style: Fig.t(context, size: AppFontSizes.microCaps, color: e.tag.$2),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            AppDateFormat.time(context, e.time),
            style: Fig.t(context, size: AppFontSizes.microCaps, color: Fig.muted),
          ),
        ],
      ),
    );
  }
}
