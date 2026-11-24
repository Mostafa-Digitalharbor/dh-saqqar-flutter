import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/mini_chip.dart';
import '../../../shared/fig/fig_page.dart';
import '../data/voice_support_api.dart';
import '../data/voice_support_models.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../shared/fig/fig.dart';

/// §8 — the support workspace, mirroring the web's `/voice-support/` page.
///
/// The name is the web's. Nothing here is audio: the user types a problem,
/// the server drafts a diagnosis and a reply, and the user may file it as a
/// real Odoo helpdesk ticket. That last action is the only write in the
/// feature, has no approval card by the backend's design, and therefore asks
/// for confirmation here before it fires.
///
/// This screen is reached from the tools sheet, which only shows the row when
/// `saqqar_features.voice_support` is true — a flag that is staff-only during
/// rollout. It is not linked from anywhere else, so an account without the
/// flag has no path to it.
class VoiceSupportScreen extends StatefulWidget {
  const VoiceSupportScreen({super.key, this.environmentId});

  /// Which bound Odoo database a filed ticket is written to.
  ///
  /// Passed by the chat that opened this screen, so the ticket lands in the
  /// database the user was actually talking about. Null when the screen is
  /// reached without that context — the server then falls back to the
  /// account's first environment, which is the only environment for most
  /// accounts and the documented default for the rest.
  final String? environmentId;

  @override
  State<VoiceSupportScreen> createState() => _VoiceSupportScreenState();
}

class _VoiceSupportScreenState extends State<VoiceSupportScreen> {
  final _controller = TextEditingController();

  VoiceSupportDraft? _draft;

  /// The exact text the draft was built from.
  ///
  /// Held separately from the field because the user may keep typing after
  /// the draft comes back: the ticket must carry the words that produced
  /// *this* diagnosis, not whatever is in the box at the moment they tap
  /// file.
  String _draftedProblem = '';

  bool _drafting = false;
  bool _filing = false;

  /// Set once a ticket has been filed from the current draft, so the button
  /// can't fire twice and open two tickets for one problem.
  bool _ticketFiled = false;

  @override
  void initState() {
    super.initState();
    // Enables/disables the submit button as the user types — the repo rule is
    // that a submit stays disabled until there is a real request to send.
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() => setState(() {});

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  bool get _canSubmit => _controller.text.trim().isNotEmpty && !_drafting;

  Future<void> _requestDraft() async {
    if (!_canSubmit) return;
    final problem = _controller.text.trim();
    setState(() {
      _drafting = true;
      // A new problem invalidates the previous answer AND its filed state:
      // leaving the old draft on screen while the new one loads would let the
      // user file a ticket for a problem they already moved on from.
      _draft = null;
      _ticketFiled = false;
    });
    try {
      final draft = await context.read<VoiceSupportApi>().draft(
        problem: problem,
        lang: Localizations.localeOf(context).languageCode,
      );
      if (!mounted) return;
      setState(() {
        _draft = draft;
        _draftedProblem = problem;
      });
      if (!draft.hasContent) {
        AppToast.show(context, message: context.tr.voiceSupportEmpty);
      }
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, message: ApiErrorMapper.message(context, e));
    } finally {
      if (mounted) setState(() => _drafting = false);
    }
  }

  Future<void> _fileTicket() async {
    final draft = _draft;
    if (draft == null || _filing || _ticketFiled) return;
    final tr = context.tr;
    // The tap IS the consent as far as the server is concerned — no approval
    // card is raised for this write. So the confirmation has to happen here,
    // and it has to name what actually happens: a real ticket, in their real
    // database.
    final ok = await ConfirmDialog.show(
      context,
      title: tr.voiceSupportTicketConfirmTitle,
      body: tr.voiceSupportTicketConfirmBody,
      confirmLabel: tr.voiceSupportFileTicket,
      icon: AppIcons.shieldAlert,
    );
    if (!ok || !mounted) return;
    setState(() => _filing = true);
    try {
      final ticket = await context.read<VoiceSupportApi>().createTicket(
        draft: draft,
        transcript: _draftedProblem,
        environmentId: widget.environmentId,
      );
      if (!mounted) return;
      if (!ticket.created) {
        // A 200 with no record id. The old code called every 200 a success,
        // which is the one outcome worth guarding against here: the user
        // believes support has been contacted and stops chasing the problem.
        // Leave the button live so they can retry.
        AppToast.show(context, message: tr.voiceSupportTicketNotCreated);
        return;
      }
      setState(() => _ticketFiled = true);
      AppToast.show(
        context,
        // Helpdesk isn't installed in every database; the server saves a
        // project task instead. Say which, so nobody goes looking in the
        // wrong Odoo app.
        message: ticket.isProjectTask
            ? tr.voiceSupportTaskCreated
            : tr.voiceSupportTicketCreated,
      );
    } catch (e) {
      if (!mounted) return;
      // Includes the ordinary case of the Odoo Helpdesk module simply not
      // being installed, which the server reports in words.
      AppToast.show(context, message: ApiErrorMapper.message(context, e));
    } finally {
      if (mounted) setState(() => _filing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final s = context.saqqar;
    final draft = _draft;

    return FigPage(
      title: tr.voiceSupportTitle,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s16,
          AppSpacing.s16,
          AppSpacing.s16,
          AppSpacing.s32,
        ),
        children: [
          Text(
            tr.voiceSupportIntro,
            style: context.text.bodyMedium?.copyWith(
              color: s.muted,
              height: AppLineHeights.body,
            ),
          ),
          const SizedBox(height: AppSpacing.s14),
          AppTextField(
            controller: _controller,
            hint: tr.voiceSupportHint,
            maxLines: 5,
          ),
          const SizedBox(height: AppSpacing.s12),
          FigButton.compact(
            label: tr.voiceSupportSubmit,
            icon: AppIcons.shieldAlert,
            // Disabled until there is something to send — a request built from
            // an empty box can only come back empty.
            onPressed: _canSubmit ? _requestDraft : null,
            loading: _drafting,
          ),
          if (draft != null && draft.hasContent) ...[
            const SizedBox(height: AppSpacing.s20),
            _DraftCard(draft: draft),
            const SizedBox(height: AppSpacing.s12),
            FigButton.compact(
              secondary: true,
              label: tr.voiceSupportFileTicket,
              icon: AppIcons.check,
              // Nothing to file without a title, and never twice for one draft.
              onPressed: draft.title.isEmpty || _ticketFiled || _filing
                  ? null
                  : _fileTicket,
            ),
          ],
        ],
      ),
    );
  }
}

/// The server's draft, rendered field by field. Every section is omitted when
/// its field is empty rather than shown as an empty heading.
class _DraftCard extends StatelessWidget {
  const _DraftCard({required this.draft});

  final VoiceSupportDraft draft;

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final s = context.saqqar;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s14),
      decoration: BoxDecoration(
        color: s.surface2.withValues(
          alpha: context.alpha(AppAlphaPairs.panelCard),
        ),
        borderRadius: AppRadius.cardR,
        border: Border.all(color: s.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (draft.title.isNotEmpty)
            Text(
              draft.title,
              style: context.text.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: s.text,
              ),
            ),
          if (draft.module.isNotEmpty ||
              draft.category.isNotEmpty ||
              draft.priority.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s8),
            Wrap(
              spacing: AppSpacing.s6,
              runSpacing: AppSpacing.s6,
              children: [
                // Server labels verbatim — these are Odoo's own module and
                // category names, so translating them client-side would show
                // a name that doesn't exist in the user's database.
                for (final label in [
                  draft.module,
                  draft.category,
                  draft.priority,
                ])
                  if (label.isNotEmpty) MiniChip(label, color: s.brandCyan),
              ],
            ),
          ],
          // The server's restatement of the problem, above its answer — it
          // is what tells the user they were understood before they read the
          // reply. Sent since §8 shipped; nothing rendered it because the
          // model never read the field.
          if (draft.summary.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s14),
            _Section(title: tr.voiceSupportSummary, body: draft.summary),
          ],
          // Optional on the wire, and the second field this card was dropping
          // on the floor — the server's read of the cause is the part that
          // tells the user whether the diagnosis is worth acting on.
          if (draft.diagnosis.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s14),
            _Section(title: tr.voiceSupportDiagnosis, body: draft.diagnosis),
          ],
          if (draft.reply.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s14),
            _Section(title: tr.voiceSupportReply, body: draft.reply),
          ],
          if (draft.steps.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s14),
            _List(title: tr.voiceSupportSteps, items: draft.steps),
          ],
          if (draft.questions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s14),
            _List(title: tr.voiceSupportQuestions, items: draft.questions),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: context.text.labelSmall?.copyWith(
            color: s.muted,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.s6),
        Text(
          body,
          style: context.text.bodyMedium?.copyWith(
            color: s.text,
            height: AppLineHeights.loose,
          ),
        ),
      ],
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: context.text.labelSmall?.copyWith(
            color: s.muted,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.s6),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // A directional bullet: a hardcoded "- " leads the line in
                // LTR even when the text runs right-to-left.
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    end: AppSpacing.s8,
                    top: AppSpacing.s6,
                  ),
                  child: Container(
                    width: AppControlSizes.dotTiny,
                    height: AppControlSizes.dotTiny,
                    decoration: BoxDecoration(
                      color: s.muted,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    item,
                    style: context.text.bodySmall?.copyWith(
                      color: s.text,
                      height: AppLineHeights.loose,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
