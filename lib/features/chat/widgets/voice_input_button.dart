import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/widgets/tappable_surface.dart';
import '../../../shared/fig/fig.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/fig_metrics.dart';

/// Mic-tap → start recording. Reduced to a pure stateless button after
/// the Whisper integration (2026-05-23): the State that used to live
/// here (recorder, timer, listening flag) moved up to [_ChatScreenState]
/// so the recording surface — waveform + timer + stop / discard —
/// can REPLACE the text field inside the composer instead of just
/// pulsing a circle inside it.
///
/// The button stays disabled while `enabled == false` (env not bound /
/// agent busy / chat offline) so dictation can't start at a surface
/// that isn't ready to accept input.
class VoiceInputButton extends StatelessWidget {
  const VoiceInputButton({
    super.key,
    required this.onStart,
    required this.enabled,
  });

  /// Tap handler — the chat screen owns the recorder lifecycle (start,
  /// 120 s auto-stop, transcribe upload). Pass null to disable.
  final VoidCallback onStart;

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Tooltip(
      message: context.tr.recordVoice,
      child: TappableSurface(
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                onStart();
              }
            : null,
        child: SizedBox(
          width: AppControlSizes.iconBox,
          height: AppControlSizes.iconBox,
          child: Icon(
            AppIcons.mic,
            size: AppIconSizes.action,
            color: enabled ? s.muted : s.muted.withValues(alpha: AppAlphas.a40),
          ),
        ),
      ),
    );
  }
}

/// The redesigned recording card (figma-design / Chats — Mobile Recording):
/// "● Recording 00:12 … Max 02:00", a live waveform, then Cancel / Send.
///
/// Send stops the recorder and uploads for transcription, so while
/// [transcribing] the card swaps the waveform for a quiet "Transcribing…"
/// line and both actions go inert (the bytes have already left the device).
class RecordingOverlay extends StatefulWidget {
  const RecordingOverlay({
    super.key,
    required this.elapsed,
    required this.transcribing,
    required this.onStop,
    required this.onDiscard,
  });

  final Duration elapsed;
  final bool transcribing;
  final VoidCallback onStop;
  final VoidCallback onDiscard;

  @override
  State<RecordingOverlay> createState() => _RecordingOverlayState();
}

class _RecordingOverlayState extends State<RecordingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: AppDurations.agentPulse)
      ..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    const red = AppColors.figCFFFF6B6B;
    final busy = widget.transcribing;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s20,
        AppSpacing.s18,
        AppSpacing.s20,
        AppSpacing.s18,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) => Container(
                  width: FigMetrics.size8,
                  height: FigMetrics.size8,
                  decoration: BoxDecoration(
                    color: red.withValues(
                      alpha: busy ? 0.4 : 0.6 + 0.4 * (1 - _pulse.value),
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              Flexible(
                child: Text(
                  busy ? tr.transcribing : context.tr.figRecording,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Fig.t(context, size: AppFontSizes.body, color: red),
                ),
              ),
              if (!busy) ...[
                const SizedBox(width: AppSpacing.s10),
                Text(
                  _fmt(widget.elapsed),
                  style: Fig.t(
                    context,
                    size: AppFontSizes.body,
                    color: AppColors.figWhite,
                    weight: FontWeight.w700,
                  ),
                ),
              ],
              const Spacer(),
              Flexible(
                child: Text(
                  context.tr.figMax0200,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Fig.t(
                    context,
                    size: AppFontSizes.caption,
                    color: AppColors.figWhite.withValues(alpha: AppAlphas.a80),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s20),
          SizedBox(
            height: 40,
            child: busy
                ? const Center(
                    child: SizedBox(
                      width: FigMetrics.size22,
                      height: FigMetrics.size22,
                      child: CircularProgressIndicator(
                        strokeWidth: AppStrokeWidths.spinnerRegular,
                        color: Fig.blueBright,
                      ),
                    ),
                  )
                : _LiveWaveform(animation: _pulse),
          ),
          const SizedBox(height: AppSpacing.s18),
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Tooltip(
                    message: tr.discardRecording,
                    child: GestureDetector(
                      onTap: busy ? null : widget.onDiscard,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.s8,
                        ),
                        child: Text(
                          context.tr.figCancel,
                          style: Fig.t(
                            context,
                            size: AppFontSizes.body,
                            color: busy ? Colors.white38 : red,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Tooltip(
                message: tr.stopRecording,
                child: GestureDetector(
                  onTap: busy ? null : widget.onStop,
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s24,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(
                        0xFF2F6BF0,
                      ).withValues(alpha: busy ? 0.5 : 1),
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                    child: Text(
                      context.tr.figSend,
                      style: Fig.t(
                        context,
                        size: AppFontSizes.body,
                        color: AppColors.figWhite,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Decorative bars: a fixed pseudo-random silhouette that swells and ebbs on
/// the pulse. A stand-in for an FFT — the recorder exposes no amplitude here.
class _LiveWaveform extends StatelessWidget {
  const _LiveWaveform({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        const barW = 3.0, gap = 3.0;
        final n = ((c.maxWidth + gap) / (barW + gap)).floor().clamp(8, 80);
        return AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final t = animation.value * 6.2831853;
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                for (var i = 0; i < n; i++)
                  Container(
                    width: barW,
                    height:
                        6 +
                        32 *
                            (0.25 +
                                0.75 *
                                    ((((i * 37) % 11) / 11) * 0.6 +
                                        0.4 *
                                            (0.5 +
                                                0.5 * math.sin(t + i * 0.45)))),
                    decoration: BoxDecoration(
                      color: Fig.blueBright,
                      borderRadius: BorderRadius.circular(
                        AppRadius.waveformBar,
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
