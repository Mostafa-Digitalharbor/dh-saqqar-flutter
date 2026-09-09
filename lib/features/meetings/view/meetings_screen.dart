import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/ui_strings.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/ghost_button.dart';
import '../../../shared/widgets/preview_banner.dart';
import '../../../shared/widgets/status_pill.dart';
import '../view_model/meetings_cubit.dart';
import '../view_model/meetings_state.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/widgets/glass_card.dart';

/// Meetings transcription (API_MOBILE_NEW_ENDPOINTS.md §4.1, Vexa) — start
/// transcribing an online meeting, watch the live transcript, then stop /
/// summarize / ask questions over it.
///
/// The §4 endpoints ship without documented payloads, so this is a
/// deliberately simple, resilient surface (raw transcript text, one-shot
/// Q&A). The per-route [MeetingsCubit] cancels its poll timer on pop.
class MeetingsScreen extends StatefulWidget {
  const MeetingsScreen({super.key});

  @override
  State<MeetingsScreen> createState() => _MeetingsScreenState();
}

class _MeetingsScreenState extends State<MeetingsScreen> {
  final _url = TextEditingController();
  final _ask = TextEditingController();
  String? _urlError;

  @override
  void dispose() {
    _url.dispose();
    _ask.dispose();
    super.dispose();
  }

  void _start() {
    if (_url.text.trim().isEmpty) {
      setState(() => _urlError = context.tr.meetingsUrlRequired);
      return;
    }
    setState(() => _urlError = null);
    FocusScope.of(context).unfocus();
    context.read<MeetingsCubit>().start(_url.text);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Scaffold(
      backgroundColor: s.bg,
      appBar: AppBar(title: Text(context.tr.meetingsTitle)),
      body: AmbientBackground(
        child: BlocConsumer<MeetingsCubit, MeetingsState>(
          listenWhen: (p, n) => p.error != n.error && n.error != null,
          listener: (context, state) {
            AppToast.show(
              context,
              message: ApiErrorMapper.message(context, state.error),
              variant: ToastVariant.error,
            );
          },
          builder: (context, state) => ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s16,
              AppSpacing.s16,
              AppSpacing.s16,
              AppSpacing.s28,
            ),
            children: [
              PreviewBanner(text: context.tr.meetingsPreviewNote),
              const SizedBox(height: AppSpacing.s14),
              if (state.session == null || !state.session!.isValid)
                _StartForm(
                  controller: _url,
                  error: _urlError,
                  busy: state.busy,
                  onStart: _start,
                )
              else
                _SessionView(state: state, askController: _ask),
            ],
          ),
        ),
      ),
    );
  }
}

class _StartForm extends StatelessWidget {
  const _StartForm({
    required this.controller,
    required this.error,
    required this.busy,
    required this.onStart,
  });

  final TextEditingController controller;
  final String? error;
  final bool busy;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.tr.meetingsIntro,
            style: context.text.bodyMedium?.copyWith(color: s.muted)),
        const SizedBox(height: AppSpacing.s18),
        AppTextField(
          label: context.tr.meetingsUrlLabel,
          controller: controller,
          errorText: error,
          keyboardType: TextInputType.url,
          hint: UiStrings.meetingUrlExample,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onStart(),
        ),
        const SizedBox(height: AppSpacing.s18),
        GhostButton(
          label: context.tr.meetingsStart,
          icon: AppIcons.recordDot,
          expand: true,
          loading: busy,
          onPressed: busy ? null : onStart,
        ),
      ],
    );
  }
}

class _SessionView extends StatelessWidget {
  const _SessionView({required this.state, required this.askController});

  final MeetingsState state;
  final TextEditingController askController;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final session = state.session!;
    final cubit = context.read<MeetingsCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.tr.meetingsStatus,
                style: context.text.labelMedium?.copyWith(color: s.muted),
              ),
            ),
            StatusPill(
              label: session.status.isEmpty ? '—' : session.status,
              variant: session.isActive
                  ? StatusPillVariant.success
                  : StatusPillVariant.info,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s12),
        Row(
          children: [
            Expanded(
              child: GhostButton(
                label: context.tr.meetingsStop,
                icon: AppIcons.stopCircle,
                tone: GhostButtonTone.danger,
                expand: true,
                onPressed:
                    (state.busy || !session.isActive) ? null : cubit.stop,
              ),
            ),
            const SizedBox(width: AppSpacing.s10),
            Expanded(
              child: GhostButton(
                label: context.tr.meetingsSummarize,
                icon: AppIcons.fileText,
                expand: true,
                onPressed: state.busy ? null : cubit.summarize,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s16),
        _TextBlock(
          title: context.tr.meetingsTranscript,
          body: state.transcript.isEmpty
              ? context.tr.meetingsTranscriptEmpty
              : state.transcript,
          mono: true,
          onRefresh: cubit.refreshTranscript,
        ),
        if (state.summary.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s14),
          _TextBlock(title: context.tr.meetingsSummary, body: state.summary),
        ],
        const SizedBox(height: AppSpacing.s16),
        AppTextField(
          label: context.tr.meetingsAskLabel,
          controller: askController,
          textInputAction: TextInputAction.send,
          onSubmitted: cubit.ask,
        ),
        const SizedBox(height: AppSpacing.s10),
        GhostButton(
          label: context.tr.meetingsAsk,
          icon: AppIcons.qa,
          expand: true,
          loading: state.busy,
          onPressed: state.busy ? null : () => cubit.ask(askController.text),
        ),
        if (state.chatReply.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s14),
          _TextBlock(title: context.tr.meetingsReply, body: state.chatReply),
        ],
      ],
    );
  }
}

class _TextBlock extends StatelessWidget {
  const _TextBlock({
    required this.title,
    required this.body,
    this.mono = false,
    this.onRefresh,
  });

  final String title;
  final String body;
  final bool mono;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return GlassCard.flat(
      padding: const EdgeInsets.all(AppSpacing.s14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: context.text.labelMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (onRefresh != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(AppIcons.refresh, size: AppIconSizes.regular, color: s.muted),
                  onPressed: onRefresh,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          SelectableText(
            body,
            style: mono
                ? context.text.bodySmall
                    ?.copyWith(fontFamily: AppTypography.fontMono)
                : context.text.bodyMedium?.copyWith(height: AppLineHeights.reading),
          ),
        ],
      ),
    );
  }
}
