import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/constants/ui_strings.dart';
import '../../core/i18n/app_date_format.dart';
import '../../core/routing/route_names.dart';
import '../../core/state/data_state.dart';
import '../../shared/fig/fig.dart';
import '../../shared/widgets/saqqar_logo.dart';
import '../auth/view_model/auth_cubit.dart';
import '../conversations/view_model/conversations_cubit.dart';
import '../notifications/data/notifications_store.dart';
import '../vault/view_model/vault_cubit.dart';
import '../vault/view_model/vault_state.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/constants/asset_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_sizes.dart';
import '../../core/theme/fig_metrics.dart';

/// Home tab: logo + avatar + bell, the orb, the greeting and "Recently
/// Chats". A first-time user with no Odoo environment is sent to the setup
/// wizard once.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static bool _setupPrompted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final conv = context.read<ConversationsCubit>();
      // Cold open loads; a return to Home revalidates in place, so a chat started
      // elsewhere (e.g. launched from Apps) shows up without a pull-to-refresh.
      if (conv.state.data.dataOrNull == null) {
        conv.load();
      } else {
        conv.refresh();
      }
      final vault = context.read<VaultCubit>();
      if (vault.state.data.dataOrNull == null) vault.load();
    });
  }

  void _maybeSetup(VaultState s) {
    final data = s.data.dataOrNull;
    if (data == null || _setupPrompted) return;
    if (data.projects.every((p) => p.environments.isEmpty)) {
      _setupPrompted = true;
      context.push(RouteNames.setupCompanyPath);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select<AuthCubit, String>(
      (c) => c.state.user?.firstName.trim().isNotEmpty == true
          ? c.state.user!.firstName.trim()
          : (c.state.user?.displayName ?? ''),
    );
    final chats = context
        .select<
          ConversationsCubit,
          List<({String id, String title, DateTime at})>
        >((c) {
          final data = c.state.data.dataOrPrevious;
          if (data == null) return const [];
          return [
            for (final e in data.ordered.where((e) => !e.isArchived).take(3))
              (id: e.id, title: e.title, at: e.updatedAt),
          ];
        });
    // Not yet fetched is not the same as "no chats": showing "start your first
    // conversation" while the list is still loading told returning users they
    // had no history.
    final chatsPending = context.select<ConversationsCubit, bool>((c) {
      final d = c.state.data;
      return d.dataOrPrevious == null && (d is DataIdle || d.isLoading);
    });
    final unread = context.watch<NotificationsStore>().hasUnread;
    return BlocListener<VaultCubit, VaultState>(
      listener: (_, s) => _maybeSetup(s),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: figLightStatusBar,
        child: FigBackdrop(
          child: SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.s24, 0, AppSpacing.s24, AppSpacing.s130),
              children: [
                const SizedBox(height: AppSpacing.s38),
                Row(
                  children: [
                    const SaqqarLogo(height: 24, forceVariant: Brightness.dark),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => context.push(RouteNames.accountPath),
                      child: ClipOval(
                        child: Image.asset(
                          AssetPaths.avatar,
                          width: FigMetrics.size40, height: FigMetrics.size40,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    GestureDetector(
                      onTap: () => context.push(RouteNames.notificationsPath),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: FigMetrics.size40, height: FigMetrics.size40,
                            decoration: const BoxDecoration(
                              color: Fig.dividerSoft,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              LucideIcons.bell,
                              size: AppIconSizes.bell,
                              color: AppColors.figCFF1A1C22,
                            ),
                          ),
                          if (unread)
                            Positioned(
                              right: AppSpacing.s9,
                              top: AppSpacing.s9,
                              child: Container(
                                width: FigMetrics.size8, height: FigMetrics.size8,
                                decoration: BoxDecoration(
                                  color: AppColors.brandPurple,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Fig.dividerSoft,
                                    width: AppBorderWidths.thick,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s56),
                const Orb(size: FigMetrics.iconFig74),
                const SizedBox(height: AppSpacing.s28),
                Text(
                  user.isEmpty
                      ? context.tr.figHelloNhowCanIHelpNyou
                      : context.tr.figHelloNhowCanIHelpNyou2(user),
                  style:
                      Fig.t(
                        context,
                        size: FigMetrics.fontFig36,
                        color: AppColors.figWhite,
                        height: FigMetrics.lhFig108,
                      ).copyWith(
                        // The glow turns pale behind the last line; this keeps the
                        // white readable without touching the artwork.
                        shadows: const [
                          Shadow(
                            color: Fig.shadowInk,
                            blurRadius: FigMetrics.blur14,
                            offset: FigOffsets.oU0U2,
                          ),
                        ],
                      ),
                ),
                const SizedBox(height: AppSpacing.s46),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.tr.figRecentlyChats,
                        style: Fig.t(context, size: AppFontSizes.markdownH1, color: Fig.inkBlack),
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => context.push(
                        RouteNames.chatPath(UiStrings.newConversationId),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(AppSpacing.s4),
                        child: Icon(
                          LucideIcons.plus,
                          size: AppIconSizes.navBar,
                          color: Fig.inkBlack,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s16),
                if (chatsPending)
                  const SizedBox.shrink()
                else if (chats.isEmpty)
                  _ChatTile(
                    title: context.tr.figStartYourFirstConversation,
                    onTap: () => context.push(
                      RouteNames.chatPath(UiStrings.newConversationId),
                    ),
                  )
                else
                  for (final c in chats)
                    _ChatTile(
                      title: c.title.isEmpty ? context.tr.figNewChat2 : c.title,
                      subtitle: AppDateFormat.relative(context, c.at),
                      onTap: () => context.push(RouteNames.chatPath(c.id)),
                    ),
                if (!chatsPending && chats.isNotEmpty)
                  _ChatTile(
                    title: context.tr.homeViewAllChats,
                    icon: LucideIcons.messagesSquare,
                    onTap: () => context.go(RouteNames.chatsPath),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The iridescent orb that stands in for the assistant.
class Orb extends StatelessWidget {
  const Orb({super.key, this.size = FigMetrics.size74});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Image.asset(
        AssetPaths.orb,
        width: size,
        height: size,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({
    required this.title,
    this.subtitle,
    this.icon,
    required this.onTap,
  });

  final String title;
  final IconData? icon;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s16),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 66,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s20),
          decoration: BoxDecoration(
            color: AppColors.figWhite.withValues(alpha: AppAlphas.a34),
            borderRadius: BorderRadius.circular(FigMetrics.radFig33),
            border: Border.all(color: AppColors.figWhite.withValues(alpha: AppAlphas.a75)),
            boxShadow: [
              BoxShadow(
                color: AppColors.figCFF8E97B8.withValues(alpha: AppAlphas.a12),
                blurRadius: FigMetrics.blur14,
                offset: FigOffsets.oU0U4,
              ),
            ],
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: AppIconSizes.action, color: Fig.navy),
                const SizedBox(width: AppSpacing.s12),
              ],
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Fig.t(
                        context,
                        size: AppFontSizes.body,
                        weight: FontWeight.w600,
                        color: Fig.navy,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Fig.t(
                          context,
                          size: AppFontSizes.metaLine,
                          color: Fig.mutedIndigo,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                Directionality.of(context) == TextDirection.rtl
                    ? LucideIcons.chevronLeft
                    : LucideIcons.chevronRight,
                size: AppIconSizes.action,
                color: Fig.mutedIndigo,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
