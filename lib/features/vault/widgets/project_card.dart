import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../data/project_models.dart';

/// One [Project] rendered to the Saqqar Design System's Projects language:
/// a glass **header card** (database glyph + name + a stats line of
/// environments · live · credentials, with manage / delete actions), followed
/// by a separate glass **environment list card** — a flat list of rows, each a
/// status-tinted server glyph, name + state pill (Live / Read-only / Idle), a
/// monospace host, credential-kind glyph squares, and a last-sync stamp.
///
/// Mirrors the production data model: credentials nest under environments,
/// environments nest under projects.
class ProjectCard extends StatelessWidget {
  const ProjectCard({
    super.key,
    required this.project,
    required this.environments,
    required this.onEnvTap,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onLongPress,
  });

  final Project project;
  final List<Environment> environments;
  final ValueChanged<Environment> onEnvTap;

  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final liveCount = environments.where((e) => e.isLive).length;
    final connected = environments.where((e) => e.hasXmlrpc).length;
    final stats = context.tr.projectStats(
      environments.length,
      liveCount,
      connected,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Project header card ──────────────────────────────────────
        DecoratedBox(
          decoration: BoxDecoration(
            color: s.cardBg,
            borderRadius: AppRadius.cardR,
            border: Border.all(color: s.cardBorder),
            boxShadow: s.glassShadow,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: AppRadius.cardR,
            child: InkWell(
              onTap: onTap,
              onLongPress: onLongPress == null
                  ? null
                  : () {
                      HapticFeedback.mediumImpact();
                      onLongPress!();
                    },
              borderRadius: AppRadius.cardR,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 8, 16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: s.brandCyan.withValues(alpha: 0.12),
                        borderRadius: AppRadius.buttonR,
                        border: Border.all(
                          color: s.brandCyan.withValues(alpha: 0.28),
                        ),
                      ),
                      child:
                          Icon(AppIcons.database, color: s.brandCyan, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            project.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            stats,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.bodySmall
                                ?.copyWith(color: s.muted),
                          ),
                        ],
                      ),
                    ),
                    if (onEdit != null || onTap != null)
                      IconButton(
                        icon: Icon(AppIcons.edit, size: 20, color: s.muted),
                        tooltip: context.tr.edit,
                        onPressed: onEdit ?? onTap,
                        visualDensity: VisualDensity.compact,
                      ),
                    if (onDelete != null)
                      IconButton(
                        icon: Icon(AppIcons.trash, size: 20, color: s.muted),
                        tooltip: context.tr.delete,
                        onPressed: onDelete,
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (environments.isNotEmpty) ...[
          const SizedBox(height: 14),
          // ── Flat environment list card ─────────────────────────────
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: s.cardBg,
              borderRadius: AppRadius.cardR,
              border: Border.all(color: s.cardBorder),
              boxShadow: s.glassShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < environments.length; i++) ...[
                  if (i > 0) Divider(color: s.border, height: 1),
                  _EnvironmentRow(
                    env: environments[i],
                    onTap: () => onEnvTap(environments[i]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _EnvironmentRow extends StatelessWidget {
  const _EnvironmentRow({required this.env, required this.onTap});

  final Environment env;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    // Status tint drives the glyph plate + status pill, mirroring the
    // design's live / read-only / idle treatment.
    final Color tint = env.isLive
        ? s.success
        : env.readOnly
            ? s.muted
            : s.muted;

    // Host + last-sync aren't carried by the API's environment model, so we
    // don't render them (they used to be fabricated from the id hash). Only
    // real fields are shown: name, live/read-only/idle state, and whether
    // credentials are configured. [slug] is the one real secondary
    // identifier the server returns.
    final ar = context.locale.languageCode == 'ar';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 15, 12, 15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatusServerGlyph(env: env, tint: tint),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            env.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (env.isLive)
                          _SoftPill(
                            label: context.tr.liveBadge,
                            tone: s.success,
                            dot: true,
                          )
                        else if (env.readOnly)
                          _SoftPill(
                              label: context.tr.readOnlyBadge, tone: s.muted)
                        else
                          _SoftPill(label: _idleLabel(context), tone: s.muted),
                      ],
                    ),
                    // Real env slug (the server's stable identifier) shown in
                    // monospace, when present. No fabricated host/sync.
                    if (env.slug.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        env.slug,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: TextDirection.ltr,
                        style: context.text.bodySmall?.copyWith(
                          color: s.muted,
                          fontFamily: 'JetBrainsMono',
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        if (env.hasXmlrpc)
                          const _TypeGlyph(icon: AppIcons.database)
                        else
                          Text(
                            _noCreds(context),
                            style: context.text.labelMedium
                                ?.copyWith(color: s.muted),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Icon(
                  ar ? AppIcons.chevronLeft : AppIcons.chevronRight,
                  size: 20,
                  color: s.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _idleLabel(BuildContext context) => context.tr.idleBadge;

  String _noCreds(BuildContext context) => context.tr.envNoCredentials;
}

/// Server glyph in a tinted rounded square with a status accent — a live
/// green dot or a read-only lock badge.
class _StatusServerGlyph extends StatelessWidget {
  const _StatusServerGlyph({required this.env, required this.tint});

  final Environment env;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return SizedBox(
      width: 42,
      height: 42,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Color.alphaBlend(tint.withValues(alpha: 0.12), s.surface3),
              borderRadius: AppRadius.buttonR,
              border: Border.all(
                color: Color.alphaBlend(tint.withValues(alpha: 0.26), s.border),
              ),
            ),
            child: Icon(AppIcons.server, color: tint, size: 19),
          ),
          if (env.isLive)
            PositionedDirectional(
              bottom: -2,
              end: -2,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: s.success,
                  border: Border.all(color: s.surface, width: 2),
                ),
              ),
            )
          else if (env.readOnly)
            PositionedDirectional(
              bottom: -3,
              end: -3,
              child: Container(
                width: 16,
                height: 16,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: s.surface,
                  border: Border.all(color: s.border),
                ),
                child: Icon(AppIcons.lock, size: 9, color: s.muted),
              ),
            ),
        ],
      ),
    );
  }
}

/// Soft uppercase status pill (matches the design's StatusPill `soft`).
class _SoftPill extends StatelessWidget {
  const _SoftPill({required this.label, required this.tone, this.dot = false});

  final String label;
  final Color tone;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.14),
        borderRadius: AppRadius.pillR,
        border: Border.all(color: tone.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(shape: BoxShape.circle, color: tone),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              height: 1.2,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: tone,
            ),
          ),
        ],
      ),
    );
  }
}

/// Credential-kind glyph — a small tinted square carrying the kind icon, no
/// label (mirrors the design's row of credential-type squares).
class _TypeGlyph extends StatelessWidget {
  const _TypeGlyph({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: s.surface3,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: s.border),
      ),
      child: Icon(icon, size: 12, color: s.brandCyan),
    );
  }
}
