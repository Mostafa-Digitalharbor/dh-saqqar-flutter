import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/routing/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';
import '../../features/chat/state/running_agents_controller.dart';
import '../extensions/context_extensions.dart';
import 'offline_banner.dart';
import 'saqqar_screen.dart';

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
          _SaqqarBrandHeader(
            title: widget.title,
            actions: widget.actions,
            elevated: _isScrolled,
          ),
          const OfflineBanner(),
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
class _SaqqarBrandHeader extends ConsumerWidget {
  const _SaqqarBrandHeader({
    required this.title,
    required this.actions,
    required this.elevated,
  });

  final String title;
  final List<Widget>? actions;
  final bool elevated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.saqqar;
    final agentRunning = ref.watch(hasAnyAgentRunningProvider);
    // Resting shadow is barely-there so the bar blends with the surface
    // at scroll position 0. As the user scrolls, the shadow lifts to
    // signal "this chrome is now over content" — same pattern iOS uses.
    final shadowAlpha = elevated
        ? (context.isDark ? 0.45 : 0.12)
        : (context.isDark ? 0.18 : 0.03);
    final blur = elevated ? 14.0 : 6.0;
    final offsetY = elevated ? 4.0 : 1.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        // Two-stop vertical gradient — top has a hair of brand-cyan
        // tint, fades to plain surface by the bottom. Gives the bar
        // depth without reading as "tinted" or heavy.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.alphaBlend(
              AppColors.brandCyan.withValues(alpha: context.isDark ? 0.05 : 0.025),
              s.surface,
            ),
            s.surface,
          ],
          stops: const [0.0, 0.85],
        ),
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
        // The brand row is locale-locked to LTR so the wordmark always
        // sits on the visual left and the page label on the right —
        // matches the desktop site, which keeps "Saqqar" on the left
        // in both EN and AR. The page label text itself is still
        // rendered with its natural script direction (Arabic letters
        // remain RTL inside the LTR container), so localised labels
        // read correctly.
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 56,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
                child: Row(
              children: [
                // Start side: brand wordmark with the cyan→purple gradient
                // (ShaderMask paints over the white text so the gradient
                // shows through letterforms cleanly).
                ShaderMask(
                  shaderCallback: (rect) =>
                      AppGradients.vivid.createShader(Offset.zero & rect.size),
                  blendMode: BlendMode.srcIn,
                  child: const Text(
                    'Saqqar',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                      height: 1.0,
                    ),
                  ),
                ),
                // Cross-tab "agent is working" pulse — slides in next to
                // the wordmark the moment any conversation pushes itself
                // into the running set, slides out when the last one
                // finishes. Keeps the chrome quiet at rest, informative
                // when busy.
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
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
                const Spacer(),
                if (actions != null) ...[
                  ...actions!,
                  // Thin vertical hairline divider between the action
                  // icons and the contextual page label — visually
                  // organises the right side into "what I can do" vs
                  // "where I am".
                  const SizedBox(width: 4),
                  Container(
                    width: 1,
                    height: 16,
                    color: s.cardBorder,
                  ),
                  const SizedBox(width: 10),
                ],
                // End side: contextual page label as a compact eyebrow
                // (uppercase + tracking) with a brand-cyan leading dot.
                // The eyebrow shape reads as "you are on X" without
                // competing with the wordmark for visual weight.
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.brandCyan,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.brandCyan.withValues(alpha: 0.45),
                        blurRadius: 6,
                        spreadRadius: 0.5,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  title.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelMedium?.copyWith(
                    color: s.text.withValues(alpha: 0.82),
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(width: 12),
                // User avatar — taps reveal a small menu with quick
                // shortcuts (Account, Sign out). Lives on every tab so
                // the user always has a 2-tap path to sign out without
                // hunting for the Account screen.
                const _UserAvatarMenu(),
              ],
            ),
          ),
        ),
            // Brand-accent hairline — 1.5 dp gradient strip across the
            // full width, the signature touch that turns a plain
            // shadowed bar into a recognisably-Saqqar one. Sits below
            // the action row so it always reads as "this header is
            // ours" without screaming for attention.
            Container(
              height: 1.5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    AppColors.brandCyan.withValues(alpha: 0.0),
                    AppColors.brandCyan.withValues(alpha: 0.55),
                    AppColors.brandPurple.withValues(alpha: 0.55),
                    AppColors.brandPurple.withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.35, 0.65, 1.0],
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

/// Per-action shortcut emitted by the user avatar menu. Kept private
/// to the scaffold because no one else has a reason to fan-out on it.
enum _UserMenuAction { account, signOut }

/// Circular user avatar in the brand bar's end slot. Tapping opens a
/// [PopupMenuButton] with quick shortcuts — Account (jumps to the
/// Account tab) and Sign out (returns to /sign-in). Same surface every
/// tab inherits so the user has a 2-tap escape hatch from anywhere.
class _UserAvatarMenu extends StatelessWidget {
  const _UserAvatarMenu();

  void _handle(BuildContext context, _UserMenuAction action) {
    switch (action) {
      case _UserMenuAction.account:
        context.go(RouteNames.accountPath);
      case _UserMenuAction.signOut:
        context.go(RouteNames.signInPath);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final initial = context.tr.sampleUsername
        .characters
        .firstOrNull
        ?.toUpperCase() ??
        'U';
    return PopupMenuButton<_UserMenuAction>(
      tooltip: context.tr.tabAccount,
      offset: const Offset(0, 40),
      color: s.surface,
      surfaceTintColor: Colors.transparent,
      onSelected: (a) => _handle(context, a),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: _UserMenuAction.account,
          child: Row(
            children: [
              Icon(Icons.person_outline, size: 18, color: s.text),
              const SizedBox(width: 10),
              Text(context.tr.tabAccount),
            ],
          ),
        ),
        PopupMenuItem(
          value: _UserMenuAction.signOut,
          child: Row(
            children: [
              const Icon(Icons.logout_rounded, size: 18, color: AppColors.danger),
              const SizedBox(width: 10),
              Text(
                context.tr.signOut,
                style: const TextStyle(color: AppColors.danger),
              ),
            ],
          ),
        ),
      ],
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppGradients.vivid,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 0.8,
          ),
        ),
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            height: 1.0,
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
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

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
      label: 'Agent working',
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final t = reduceMotion ? 1.0 : Curves.easeInOut.transform(_ctrl.value);
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
    );
  }
}
