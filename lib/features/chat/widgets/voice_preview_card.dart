import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/fig_metrics.dart';
import '../../../shared/fig/fig.dart';

/// What the preview card needs from an audio player — kept this small so a
/// test can stand in for the plugin, which has no test implementation.
abstract class VoicePlayback {
  /// Emits true while playing and false once paused or finished.
  Stream<bool> get playing;

  /// Emits the play position as it advances.
  Stream<Duration> get position;

  Future<void> play(File file);
  Future<void> pause();
  Future<void> dispose();
}

/// [VoicePlayback] over the `audioplayers` plugin.
class AudioplayersPlayback implements VoicePlayback {
  AudioplayersPlayback() : _player = AudioPlayer();

  final AudioPlayer _player;

  @override
  Stream<bool> get playing =>
      _player.onPlayerStateChanged.map((s) => s == PlayerState.playing);

  @override
  Stream<Duration> get position => _player.onPositionChanged;

  @override
  Future<void> play(File file) => _player.play(DeviceFileSource(file.path));

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> dispose() => _player.dispose();
}

/// The "Voice message · Preview" card shown after a recording stops: listen to
/// the take, then send it (which transcribes it into the composer) or cancel.
class VoicePreviewCard extends StatefulWidget {
  const VoicePreviewCard({
    super.key,
    required this.file,
    required this.length,
    required this.sending,
    this.progress = 0,
    required this.onSend,
    required this.onCancel,
    this.playback,
  });

  final File file;
  final Duration length;

  /// True while the take is uploading; both buttons are inert then.
  final bool sending;

  /// How much of the take has been uploaded (0..1) while [sending].
  final double progress;
  final VoidCallback onSend;
  final VoidCallback onCancel;

  /// Test seam. Null means the real plugin, created on first play.
  final VoicePlayback? playback;

  @override
  State<VoicePreviewCard> createState() => _VoicePreviewCardState();
}

class _VoicePreviewCardState extends State<VoicePreviewCard> {
  static const _bars = 40;

  VoicePlayback? _playback;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<Duration>? _positionSub;
  bool _playing = false;
  Duration _position = Duration.zero;

  late final List<double> _heights = _barHeights(widget.file.path);

  /// A stable pseudo-waveform: the take's amplitude is not recorded, so the
  /// bars are derived from the file path — the same take always draws the
  /// same shape, and nothing here pretends to be a measurement.
  static List<double> _barHeights(String seed) {
    final random = math.Random(seed.hashCode);
    return [for (var i = 0; i < _bars; i++) 0.25 + random.nextDouble() * 0.75];
  }

  VoicePlayback _ensurePlayback() {
    final existing = _playback;
    if (existing != null) return existing;
    final created = widget.playback ?? AudioplayersPlayback();
    _playingSub = created.playing.listen((p) {
      if (!mounted) return;
      setState(() {
        _playing = p;
        if (!p && _position >= widget.length) _position = Duration.zero;
      });
    });
    _positionSub = created.position.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    return _playback = created;
  }

  Future<void> _togglePlay() async {
    final playback = _ensurePlayback();
    if (_playing) {
      await playback.pause();
    } else {
      await playback.play(widget.file);
    }
  }

  @override
  void dispose() {
    unawaited(_playingSub?.cancel());
    unawaited(_positionSub?.cancel());
    unawaited(_playback?.dispose());
    super.dispose();
  }

  String _fmt(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  /// The Figma "Sending..." card: a percentage ring, the waveform filling as
  /// bytes go out, the time uploaded / total and a thin bar.
  Widget _buildSending(BuildContext context) {
    final tr = context.tr;
    final fraction = widget.progress.clamp(0.0, 1.0);
    final uploaded = Duration(
      milliseconds: (widget.length.inMilliseconds * fraction).round(),
    );
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final small = Fig.t(
      context,
      size: AppFontSizes.caption,
      color: AppColors.figWhite.withValues(alpha: AppAlphas.a80),
    );
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: FigMetrics.size46,
                height: FigMetrics.size46,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: fraction,
                        strokeWidth: AppStrokeWidths.spinnerRegular,
                        color: Fig.blueBright,
                        backgroundColor: AppColors.figWhite.withValues(
                          alpha: AppAlphas.a20,
                        ),
                      ),
                    ),
                    Text(
                      '${(fraction * 100).round()}%',
                      style: Fig.t(
                        context,
                        size: AppFontSizes.caption,
                        color: AppColors.figWhite,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s14),
              Expanded(
                child: SizedBox(
                  height: FigMetrics.size36,
                  child: CustomPaint(
                    painter: _WaveformPainter(
                      heights: _heights,
                      progress: fraction,
                      rtl: rtl,
                      played: Fig.blueBright,
                      rest: AppColors.figWhite.withValues(alpha: AppAlphas.a50),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          Row(
            children: [
              Expanded(child: Text(_fmt(uploaded), style: small)),
              Expanded(
                child: Text(
                  _fmt(widget.length),
                  style: small,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s6),
          LinearProgressIndicator(
            value: fraction,
            minHeight: AppStrokeWidths.spinnerRegular,
            color: Fig.blueBright,
            backgroundColor: AppColors.figWhite.withValues(
              alpha: AppAlphas.a20,
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(tr.voiceSending, style: small),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sending) return _buildSending(context);
    final tr = context.tr;
    const red = AppColors.figCFFFF6B6B;
    final total = widget.length.inMilliseconds;
    final progress = total <= 0
        ? 0.0
        : (_position.inMilliseconds / total).clamp(0.0, 1.0);
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
              Flexible(
                child: Text(
                  tr.voiceMessageLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Fig.t(
                    context,
                    size: AppFontSizes.body,
                    color: AppColors.figWhite,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s10),
              Text(
                _fmt(widget.length),
                style: Fig.t(
                  context,
                  size: AppFontSizes.body,
                  color: AppColors.figWhite,
                  weight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  tr.voicePreviewLabel,
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
          const SizedBox(height: AppSpacing.s16),
          Row(
            children: [
              Semantics(
                button: true,
                label: _playing ? tr.voicePause : tr.voicePlay,
                child: GestureDetector(
                  onTap: widget.sending ? null : _togglePlay,
                  child: Container(
                    width: FigMetrics.size46,
                    height: FigMetrics.size46,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Fig.blueAction,
                    ),
                    child: Icon(
                      _playing ? LucideIcons.pause : LucideIcons.play,
                      size: AppIconSizes.regular,
                      color: AppColors.figWhite,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s14),
              Expanded(
                child: SizedBox(
                  height: FigMetrics.size36,
                  child: CustomPaint(
                    painter: _WaveformPainter(
                      heights: _heights,
                      progress: progress,
                      rtl: Directionality.of(context) == TextDirection.rtl,
                      played: Fig.blueBright,
                      rest: AppColors.figWhite.withValues(alpha: AppAlphas.a50),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s18),
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: GestureDetector(
                    onTap: widget.sending ? null : widget.onCancel,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.s8,
                      ),
                      child: Text(
                        tr.figCancel,
                        style: Fig.t(
                          context,
                          size: AppFontSizes.body,
                          color: widget.sending ? Colors.white38 : red,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: widget.sending ? null : widget.onSend,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s28,
                    vertical: AppSpacing.s12,
                  ),
                  decoration: BoxDecoration(
                    color: Fig.blueAction,
                    borderRadius: BorderRadius.circular(FigMetrics.radFig21),
                  ),
                  child: widget.sending
                      ? const SizedBox(
                          width: FigMetrics.size18,
                          height: FigMetrics.size18,
                          child: CircularProgressIndicator(
                            strokeWidth: AppStrokeWidths.spinnerRegular,
                            color: AppColors.figWhite,
                          ),
                        )
                      : Text(
                          tr.send,
                          style: Fig.t(
                            context,
                            size: AppFontSizes.body,
                            color: AppColors.figWhite,
                            weight: FontWeight.w600,
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

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.heights,
    required this.progress,
    required this.rtl,
    required this.played,
    required this.rest,
  });

  final List<double> heights;
  final double progress;

  /// Playback fills from the play button's side, which is the right in RTL.
  final bool rtl;
  final Color played;
  final Color rest;

  @override
  void paint(Canvas canvas, Size size) {
    final count = heights.length;
    final slot = size.width / count;
    final bar = slot * 0.55;
    for (var i = 0; i < count; i++) {
      final h = size.height * heights[i];
      final slotIndex = rtl ? count - 1 - i : i;
      final x = slot * slotIndex + (slot - bar) / 2;
      final done = (i + 1) / count <= progress;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, (size.height - h) / 2, bar, h),
          Radius.circular(bar / 2),
        ),
        Paint()..color = done ? played : rest,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.progress != progress || old.heights != heights || old.rtl != rtl;
}
