import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/extensions/context_extensions.dart';

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
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.buttonR,
        child: InkWell(
          onTap: enabled
              ? () {
                  HapticFeedback.selectionClick();
                  onStart();
                }
              : null,
          borderRadius: AppRadius.buttonR,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(
              Icons.mic,
              size: 20,
              color: enabled ? s.muted : s.muted.withValues(alpha: 0.4),
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-width strip that replaces the composer's text field while a
/// recording is in flight. Renders:
///
///   * leading "discard" X (drops the buffer, no upload),
///   * pulsing red dot,
///   * faux waveform (CSS-style — just sine-displaced bars, no FFT),
///   * monospace mm:ss timer,
///   * trailing stop / spinner.
///
/// All three states (recording, transcribing) live here so the visual
/// transition between "recording" → "transcribing" is local. The chat
/// screen owns the actual recorder + transcribe call and feeds the
/// elapsed Duration in via [elapsed].
class RecordingOverlay extends StatefulWidget {
  const RecordingOverlay({
    super.key,
    required this.elapsed,
    required this.transcribing,
    required this.onStop,
    required this.onDiscard,
  });

  final Duration elapsed;

  /// `true` once the user tapped stop and the upload is in flight.
  /// Hides the timer + waveform, shows a "Transcribing…" line + spinner
  /// where the stop button used to be.
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
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
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
    final s = context.saqqar;
    final tr = context.tr;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          // Discard — drops the recording without uploading. Disabled
          // while the upload is in flight (the audio bytes have already
          // left the device at that point).
          IconButton(
            tooltip: tr.discardRecording,
            onPressed: widget.transcribing ? null : widget.onDiscard,
            icon: Icon(Icons.delete_outline,
                size: 22,
                color: widget.transcribing ? s.muted : s.danger),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 4),
          if (widget.transcribing) ...[
            // Mid-upload: timer + waveform stand down; show a quiet
            // "Transcribing…" line + spinner instead. Same row height
            // either way so the composer doesn't jump.
            Expanded(
              child: Text(
                tr.transcribing,
                style: context.text.bodyMedium?.copyWith(
                  color: s.muted,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: s.brandCyan,
              ),
            ),
            const SizedBox(width: 8),
          ] else ...[
            // Pulsing red dot — signals "we're capturing audio right now".
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) {
                final v = 0.55 + 0.45 * _pulse.value;
                return Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: s.danger.withValues(alpha: v),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: s.danger.withValues(alpha: 0.35 * v),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _FauxWaveform(animation: _pulse, color: s.brandCyan),
            ),
            const SizedBox(width: 10),
            Text(
              _fmt(widget.elapsed),
              style: context.text.labelMedium?.copyWith(
                color: s.text,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: tr.stopRecording,
              onPressed: widget.onStop,
              icon: Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: s.danger,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.stop_rounded,
                    color: Colors.white, size: 18),
              ),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      ),
    );
  }
}

/// Decorative bars that ride the same pulse the red dot uses. Cheap
/// stand-in for a real FFT visualisation — testers don't expect a
/// spectrum analyser, they expect "something animated that says it's
/// listening". Cost: nine `Container`s and one Animation rebuild.
class _FauxWaveform extends StatelessWidget {
  const _FauxWaveform({required this.animation, required this.color});

  final Animation<double> animation;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 22,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final t = animation.value;
          return Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (var i = 0; i < 9; i++) ...[
                _Bar(
                  height: 6 +
                      14 *
                          (0.5 +
                              0.5 *
                                  ((i.isEven ? t : 1 - t) *
                                      (1 - (i - 4).abs() / 5))),
                  color: color,
                ),
                const SizedBox(width: 4),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.height, required this.color});

  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      width: 3,
      height: height.clamp(4, 20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
