import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/fig_metrics.dart';
import '../../../shared/fig/fig.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/tappable_surface.dart';
import '../../inbox/data/artifact_downloader.dart';
import '../data/chat_view_models.dart';
import '../view/attachment_viewer_screen.dart';

/// Progress reported while an attachment downloads: a 0..1 fraction, or
/// [indeterminateProgress] when the server did not say how big the file is.
const double indeterminateProgress = -1;

/// Downloads the attachment (or reuses the cached copy under the app's
/// documents directory) and opens it in Saqqar's own viewer.
///
/// [onProgress] is told how far along the download is, and gets `null` once it
/// is over, so the card the user tapped can show it instead of a toast.
///
/// Caller must guard with `attachment.downloadUrl != null`.
Future<void> openChatAttachment(
  BuildContext context,
  ChatAttachment attachment, {
  void Function(double? progress)? onProgress,
  List<ChatAttachment>? gallery,
  CancelToken? cancelToken,
}) async {
  final url = attachment.downloadUrl;
  final cacheKey = attachment.serverId;
  if (url == null || cacheKey == null) return;
  final tr = context.tr;
  final downloader = ArtifactDownloader(context.read<Dio>());
  onProgress?.call(indeterminateProgress);
  final result = await downloader.fetch(
    url: url,
    cacheKey: cacheKey,
    originalName: attachment.name,
    kindHint: attachment.kind,
    onProgress: (received, total) =>
        onProgress?.call(total > 0 ? received / total : indeterminateProgress),
    cancelToken: cancelToken,
  );
  onProgress?.call(null);
  // The user cancelled it: say nothing, they know.
  if (cancelToken?.isCancelled ?? false) return;
  if (!context.mounted) return;
  switch (result) {
    case ArtifactFetchSuccess(:final file):
      await AttachmentViewerScreen.open(
        context,
        file: file,
        name: attachment.name,
        kindLabel: attachment.kind,
        sizeLabel: attachment.size,
        gallery: gallery == null || gallery.length < 2
            ? null
            : [
                for (final g in gallery)
                  ViewerImage(
                    name: g.name,
                    subtitle: [
                      g.kind,
                      g.size,
                    ].where((e) => e.isNotEmpty).join(' · '),
                    url: g.imageUrl,
                  ),
              ],
        galleryIndex: gallery?.indexOf(attachment) ?? 0,
      );
    case ArtifactFetchFailed(:final statusCode):
      AppToast.show(
        context,
        message: tr.artifactDownloadMessage(statusCode),
        variant: ToastVariant.error,
      );
  }
}

/// Makes [child] open [attachment] when tapped, and shows the download on the
/// card itself — a dimmed layer with the percentage and a progress bar — rather
/// than leaving the user to wonder whether the tap registered.
///
/// Not tappable (and draws [child] as is) when the attachment has no download
/// URL, e.g. a file still on its way up.
class AttachmentOpenTarget extends StatefulWidget {
  const AttachmentOpenTarget({
    super.key,
    required this.attachment,
    required this.child,
    this.gallery,
    this.inlineCard = false,
  });

  final ChatAttachment attachment;
  final Widget child;

  /// Show the download as the Figma "Downloading 42% · Cancel" card in place
  /// of [child], instead of dimming it. For a lone file; pictures keep the
  /// dimmed layer.
  final bool inlineCard;

  /// Pictures sent together with [attachment]: when given, the viewer lets
  /// the user swipe between them.
  final List<ChatAttachment>? gallery;

  @override
  State<AttachmentOpenTarget> createState() => _AttachmentOpenTargetState();
}

class _AttachmentOpenTargetState extends State<AttachmentOpenTarget> {
  double? _progress;
  CancelToken? _token;

  void _setProgress(double? value) {
    if (mounted) setState(() => _progress = value);
  }

  Future<void> _open() {
    final token = _token = CancelToken();
    return openChatAttachment(
      context,
      widget.attachment,
      onProgress: _setProgress,
      gallery: widget.gallery,
      cancelToken: token,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.attachment.downloadUrl == null) return widget.child;
    final progress = _progress;
    if (progress != null && widget.inlineCard) {
      return DownloadingFileCard(
        attachment: widget.attachment,
        progress: progress,
        onCancel: () => _token?.cancel(),
      );
    }
    return TappableSurface(
      onTap: progress == null ? _open : null,
      child: Stack(
        children: [
          widget.child,
          if (progress != null)
            Positioned.fill(child: DownloadProgressOverlay(progress: progress)),
        ],
      ),
    );
  }
}

/// The layer drawn over a card while its file downloads.
class DownloadProgressOverlay extends StatelessWidget {
  const DownloadProgressOverlay({super.key, required this.progress});

  /// 0..1, or [indeterminateProgress].
  final double progress;

  @override
  Widget build(BuildContext context) {
    final known = progress >= 0;
    return ClipRRect(
      borderRadius: AppRadius.smallR,
      child: ColoredBox(
        color: AppColors.scrimBase.withValues(alpha: AppAlphas.a55),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (known)
              Text(
                '${(progress * 100).round()}%',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.figWhite,
                  fontWeight: FontWeight.w700,
                ),
              ),
            Align(
              alignment: Alignment.bottomCenter,
              child: LinearProgressIndicator(
                value: known ? progress : null,
                minHeight: AppSpacing.s4,
                backgroundColor: AppColors.figWhite.withValues(
                  alpha: AppAlphas.a30,
                ),
                color: AppColors.figWhite,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The Figma "Downloading 42% · Cancel" card: the file, how far along it is,
/// a Cancel link and a bar across the bottom.
class DownloadingFileCard extends StatelessWidget {
  const DownloadingFileCard({
    super.key,
    required this.attachment,
    required this.progress,
    required this.onCancel,
  });

  final ChatAttachment attachment;

  /// 0..1, or [indeterminateProgress].
  final double progress;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final known = progress >= 0;
    final name = attachment.name.toLowerCase();
    final tone = name.endsWith('.pdf')
        ? Fig.fileRed
        : (name.endsWith('.xls') || name.endsWith('.xlsx'))
        ? Fig.fileGreen
        : Fig.fileBlue;
    final status = known
        ? '${tr.attachmentDownloading} ${(progress * 100).round()}%'
        : tr.attachmentDownloading;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: AppColors.figWhite.withValues(alpha: AppAlphas.a07),
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(
          color: AppColors.figWhite.withValues(alpha: AppAlphas.a18),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: FigMetrics.size40,
                height: FigMetrics.size40,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: AppAlphas.a22),
                  borderRadius: BorderRadius.circular(FigMetrics.radFig9),
                ),
                child: Icon(
                  LucideIcons.fileText,
                  size: AppIconSizes.regular,
                  color: tone,
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attachment.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Fig.t(
                        context,
                        size: AppFontSizes.dense,
                        weight: FontWeight.w600,
                        color: AppColors.figWhite,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s2),
                    Text(
                      '${attachment.size} · $status',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Fig.t(
                        context,
                        size: FigMetrics.fontFig11,
                        color: AppColors.figWhite.withValues(
                          alpha: AppAlphas.a80,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s10),
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: GestureDetector(
                    onTap: onCancel,
                    behavior: HitTestBehavior.opaque,
                    child: Text(
                      tr.figCancel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Fig.t(
                        context,
                        size: AppFontSizes.dense,
                        color: Fig.accentBlue,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s10),
          LinearProgressIndicator(
            value: known ? progress : null,
            minHeight: AppStrokeWidths.spinnerThin,
            color: Fig.accentBlue,
            backgroundColor: AppColors.figWhite.withValues(alpha: AppAlphas.a20),
          ),
        ],
      ),
    );
  }
}
