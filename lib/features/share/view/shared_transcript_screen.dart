import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_date_format.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/state/data_state.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/data_state_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/responsive_content.dart';
import '../../chat/widgets/chat_markdown.dart';
import '../../conversations/data/conversation_models.dart';
import '../data/shared_transcript_models.dart';
import '../view_model/shared_transcript_cubit.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/fig/fig_page.dart';

/// Public, read-only view of a shared conversation. Reached via the
/// `https://saqqaar.com/share/<token>` Universal / App Link or the legacy
/// `saqqar://share/<token>` scheme.
///
/// A share link is a snapshot meant to be opened by anyone (they may not even
/// have an account — the backend endpoint is unauthenticated), so this screen
/// is strictly read-only: no composer, no editing. The [SharedTranscriptCubit]
/// (provided by the router) fetches `GET /api/v1/shares/<token>/`, and
/// [DataStateView] renders the loading / data / error branches.
class SharedTranscriptScreen extends StatelessWidget {
  const SharedTranscriptScreen({super.key, required this.token});

  final String token;

  /// Leave the screen. When this route was reached from inside the app there's
  /// something to pop back to; when it was the deep-link entry point (the app
  /// was launched straight into `/share/...`) there's nothing below it, so
  /// popping would exit the app — go to Home instead so the app stays open.
  void _leave(BuildContext context) {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    } else {
      context.go(RouteNames.chatsPath);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Intercept the system back on the deep-link entry (nothing to pop) so it
    // lands on Home instead of finishing the task and bouncing the user back
    // to whatever app opened the link.
    return PopScope(
      canPop: Navigator.of(context).canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) context.go(RouteNames.chatsPath);
      },
      child: BlocBuilder<SharedTranscriptCubit, DataState<SharedTranscript>>(
        builder: (context, state) {
          final transcript = state.dataOrNull;
          final title =
              (transcript != null && transcript.title.trim().isNotEmpty)
              ? transcript.title
              : context.tr.sharedConversationTitle;
          return FigPage(
            title: title,
            // The "you can look but not touch" nature of a shared transcript,
            // as the eyebrow over its title.
            eyebrow: context.tr.readOnlyBadge,
            onBack: () => _leave(context),
            child: DataStateView<SharedTranscript>(
              state: state,
              onRetry: () => context.read<SharedTranscriptCubit>().load(token),
              onData: (context, data) => _TranscriptBody(transcript: data),
            ),
          );
        },
      ),
    );
  }
}

class _TranscriptBody extends StatelessWidget {
  const _TranscriptBody({required this.transcript});

  final SharedTranscript transcript;

  @override
  Widget build(BuildContext context) {
    // The backend only exposes user + assistant rows, but be defensive: drop
    // any tool/system rows and empty-content messages so the read-only view
    // never renders a blank bubble.
    final messages = transcript.messages
        .where(
          (m) =>
              (m.role == MessageRole.user || m.role == MessageRole.assistant) &&
              m.content.trim().isNotEmpty,
        )
        .toList();

    if (messages.isEmpty) {
      return Center(
        child: ResponsiveContent(
          maxWidth: AppLayoutWidths.transcriptHeader,
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: EmptyState(
            title: context.tr.sharedConversationTitle,
            body: context.tr.sharedConversationEmpty,
            icon: AppIcons.fileText,
          ),
        ),
      );
    }

    return ResponsiveContent(
      maxWidth: AppLayoutWidths.transcript,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // User bubbles clamp to 88% of the content width (spec §8.1); the
          // agent voice spans the full width, so it needs no cap.
          final maxBubbleWidth = constraints.maxWidth * 0.88;
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s16,
              AppSpacing.s16,
              AppSpacing.s16,
              AppSpacing.s32,
            ),
            itemCount: messages.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s16),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _UpdatedHeader(updatedAt: transcript.updatedAt);
              }
              return _SharedMessage(
                message: messages[index - 1],
                maxBubbleWidth: maxBubbleWidth,
              );
            },
          );
        },
      ),
    );
  }
}

/// Muted "last active" timestamp at the top of the transcript.
class _UpdatedHeader extends StatelessWidget {
  const _UpdatedHeader({required this.updatedAt});

  final DateTime updatedAt;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Text(
      AppDateFormat.dateTime(context, updatedAt),
      style: context.text.bodySmall?.copyWith(color: s.muted),
    );
  }
}

/// One read-only message: a cyan user bubble (end-aligned) or the bubble-less
/// agent voice (start-aligned), matching the live chat's §8 render paths.
class _SharedMessage extends StatelessWidget {
  const _SharedMessage({required this.message, required this.maxBubbleWidth});

  final Message message;
  final double maxBubbleWidth;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;

    if (message.role == MessageRole.user) {
      return Align(
        alignment: AlignmentDirectional.centerEnd,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxBubbleWidth),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s14,
              vertical: AppSpacing.s11,
            ),
            decoration: BoxDecoration(
              color: s.brandCyan.withValues(
                alpha: context.alpha(AppAlphaPairs.tint),
              ),
              border: Border.all(
                color: s.brandCyan.withValues(alpha: AppAlphas.a30),
              ),
              borderRadius: AppRadius.userBubbleR,
            ),
            child: ChatMarkdown(data: message.content, isUser: true),
          ),
        ),
      );
    }

    // Assistant — no bubble; the gradient-less brand label + markdown body is
    // what reads as "the system speaking".
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr.appName,
          style: context.text.labelSmall?.copyWith(
            color: s.brandCyan,
            fontWeight: FontWeight.w700,
            fontSize: AppFontSizes.caption,
          ),
        ),
        const SizedBox(height: AppSpacing.s4),
        ChatMarkdown(data: message.content, isUser: false),
      ],
    );
  }
}
