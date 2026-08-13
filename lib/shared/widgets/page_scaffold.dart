import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/routing/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../features/app_update/view/update_nudge_banner.dart';
import '../../features/chat/view_model/running_agents_cubit.dart';
import '../../features/notifications/data/notifications_store.dart';
import '../extensions/context_extensions.dart';
import 'offline_banner.dart';
import 'saqqar_logo.dart';
import 'saqqar_screen.dart';
import '../../core/theme/app_radius.dart';

/// Lightweight single-row chrome for every root tab:
///
///   ┌────────────────────────────────────────────────────┐
///   │ Saqqar                              [actions] Chats │
///   └────────────────────────────────────────────────────┘
///
/// Brand wordmark on the start side, contextual page label on the end
/// side, optional [actions] sit just before the label. A soft drop
/// shadow separates the chrome from the content underneath. No avatar,
/// no ambient backdrop, no big title — kept deliberately quiet so the
/// page content itself is the focus.
///
/// The legacy `subtitle` param is still accepted (some screens pass it)
/// but it's no longer rendered — the simpler bar doesn't have room for
/// it. Keep the param so we don't have to touch every call site at
/// once; callers can drop it on their next pass.
class PageScaffold extends StatefulWidget {
  const PageScaffold({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.actions,
    this.controller,
    this.floatingActionButton,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 28),
    this.onRefresh,
  });

  final String title;
  // ignore: unused_element_parameter
  final String? subtitle;
  final List<Widget> children;
  final List<Widget>? actions;
  final ScrollController? controller;
  final Widget? floatingActionButton;
  final EdgeInsetsGeometry padding;
  final Future<void> Function()? onRefresh;

  @override
  State<PageScaffold> createState() => _PageScaffoldState();
}

class _PageScaffoldState extends State<PageScaffold> {
  /// True once the user has scrolled the body past a small threshold —
  /// drives the brand header's shadow elevation so the chrome visually
  /// separates from the content the moment it starts moving.
  bool _isScrolled = false;

  bool _handleScroll(ScrollNotification n) {
    // Only react to vertical scroll on the primary scroll view; nested
    // horizontal scrollers (e.g. a chip rail) shouldn't lift the AppBar.
    if (n.metrics.axis != Axis.vertical) return false;
    final next = n.metrics.pixels > 4;
    if (next != _isScrolled) {
      setState(() => _isScrolled = next);
    }
    return false; // never consume — let the scroll view keep its event
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _SaqqarBrandHeader(title: widget.title, elevated: _isScrolled),
          const OfflineBanner(),
          // Same slot, same shape as the offline row: both are "something
          // about the app itself, not this screen" and belong under the
          // header rather than inside the scrollable content.
          const UpdateNudgeBanner(),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: _handleScroll,
              child: SaqqarScreen(
                controller: widget.controller,
                padding: widget.padding,
                onRefresh: widget.onRefresh,
                children: widget.children,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: widget.floatingActionButton,
    );
  }
}

/// The lightweight brand bar — Saqqar wordmark on the start side,
/// optional actions + page title on the end side, soft drop shadow at
/// the bottom edge. When [elevated] is true (the page has been
/// scrolled) the shadow deepens so the chrome visually separates from
/// the content.
///
/// Watches [hasAnyAgentRunningProvider] so a pulsing cyan dot appears
/// next to the brand wordmark whenever ANY conversation has the agent
/// mid-run — gives the user cross-tab "Saqqar is busy somewhere"
/// awareness even when they're not in a chat.
class _SaqqarBrandHeader extends StatelessWidget {
  const _SaqqarBrandHeader({required this.title, required this.elevated});

  final String title;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final appDir = Directionality.of(context);
    final agentRunning = context.select<RunningAgentsCubit, bool>(
      (cubit) => cubit.state.isNotEmpty,
    );
    // Resting shadow is barely-there so the bar blends with the surface
    // at scroll position 0. As the user scrolls, the shadow lifts to
    // signal "this chrome is now over content" — same pattern iOS uses.
    final shadowAlpha = elevated
        ? (context.isDark ? 0.45 : 0.12)
        : (context.isDark ? 0.18 : 0.03);
    final blur = elevated ? 14.0 : 6.0;
    final offsetY = elevated ? 4.0 : 1.0;
    return AnimatedContainer(
      duration: AppDurations.cardIn,
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: s.surface,
        border: Border(bottom: BorderSide(color: s.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: shadowAlpha),
            blurRadius: blur,
            offset: Offset(0, offsetY),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        // The chrome row is locale-locked to LTR so the brand logo always
        // sits on the visual left and the notifications bell on the right,
        // matching the Saqqar Design System header. The centered page title
        // is rendered back in its natural script direction so Arabic labels
        // read correctly.
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            height: 62,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 12, 0),
              child: Row(
                children: [
                  // Start side: the brand logo (white on the dark surface via
                  // SaqqarLogo's own tinting), framed in an elegant rounded
                  // card. Tapping it jumps to the Chats tab ("home") from any
                  // root tab.
                  InkWell(
                    onTap: () => context.go(RouteNames.chatsPath),
                    borderRadius: AppRadius.smallR,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: s.cardBg,
                        borderRadius: AppRadius.smallR,
                        border: Border.all(color: s.cardBorder),
                      ),
                      child: const SaqqarLogo(height: 27),
                    ),
                  ),
                  // Cross-tab "agent is working" pulse — slides in next to the
                  // logo whenever any conversation has the agent mid-run.
                  AnimatedSwitcher(
                    duration: AppDurations.switcherIn,
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SizeTransition(
                        sizeFactor: anim,
                        axis: Axis.horizontal,
                        child: child,
                      ),
                    ),
                    child: agentRunning
                        ? const Padding(
                            key: ValueKey('agent-pulse'),
                            padding: EdgeInsetsDirectional.only(start: 8),
                            child: _AgentPulseDot(),
                          )
                        : const SizedBox.shrink(key: ValueKey('idle')),
                  ),
                  // Title fills the space between the logo group and the bell
                  // and centres within it, so the three header elements read
                  // as evenly spaced (equal gap on each side of the title)
                  // rather than the title floating dead-centre over an
                  // unbalanced row. Horizontal padding keeps a long title off
                  // the two side elements.
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Directionality(
                        textDirection: appDir,
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: context.text.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // End side: notifications bell with an unread dot.
                  const _NotificationsBell(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rounded-square notifications bell in the brand bar's end slot — shares its
/// shape with the chat header's bell. Shows a red count badge ONLY when the
/// inbox has unread items; tapping it opens the in-app notifications inbox.
class _NotificationsBell extends StatelessWidget {
  const _NotificationsBell();

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final tr = context.tr;
    final unread = context.watch<NotificationsStore>().unreadCount;
    return Semantics(
      button: true,
      label: tr.notifications,
      child: Tooltip(
        message: tr.notifications,
        child: InkWell(
          // Rounded-square instead of a circle, matching the chat screen
          // header's bell (_InboxBellTrigger) so both headers share one
          // affordance shape.
          customBorder: const RoundedRectangleBorder(
            borderRadius: AppRadius.smallR,
          ),
          onTap: () => context.pushNamed(RouteNames.notifications),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: AppRadius.smallR,
                  color: s.cardBg,
                  border: Border.all(color: s.cardBorder),
                ),
                child: Icon(AppIcons.bell, size: 19, color: s.text),
              ),
              // Unread COUNT badge (caps at "9+"). Hidden at zero.
              if (unread > 0)
                PositionedDirectional(
                  top: -2,
                  end: -2,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: s.danger,
                      borderRadius: AppRadius.pillR,
                      border: Border.all(color: s.surface, width: 1.5),
                    ),
                    child: Text(
                      unread > 9 ? '9+' : '$unread',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 8-dp cyan dot that breathes (alpha 0.55 ↔ 1.0 over 1.4 s) to signal
/// the agent is actively working in some conversation. Self-contained
/// stateful widget so the alpha animation doesn't force the whole
/// brand bar to rebuild on every tick.
class _AgentPulseDot extends StatefulWidget {
  const _AgentPulseDot();

  @override
  State<_AgentPulseDot> createState() => _AgentPulseDotState();
}

class _AgentPulseDotState extends State<_AgentPulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: AppDurations.agentPulse,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Under OS Reduce Motion the dot renders at a constant `t = 1.0`, so
    // keeping the controller repeating would rebuild an identical frame
    // 60×/s for nothing. Stop it; otherwise pulse as before.
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      _ctrl.stop();
    } else if (!_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      liveRegion: true,
      label: context.tr.agentWorking,
      // Isolate the header pulse's per-frame repaint from the rest of the
      // brand header so it doesn't invalidate neighbouring layers each tick.
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            final t = reduceMotion
                ? 1.0
                : Curves.easeInOut.transform(_ctrl.value);
            return Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.brandCyan.withValues(alpha: 0.55 + 0.45 * t),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brandCyan.withValues(alpha: 0.35 * t),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
