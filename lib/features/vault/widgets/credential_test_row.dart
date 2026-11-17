part of 'credential_form.dart';

enum _TestStatus { idle, running, ok, failed }

/// "Test connection" affordance — a ghost button with an inline status
/// badge below. Status mirrors [_TestStatus]:
///   * `idle` → just the button, no badge
///   * `running` → button shows spinner, badge reads "Testing…"
///   * `ok` → button enabled, green "Connection OK" badge
///   * `failed` → button enabled, red `Connection failed: <reason>`
class _TestConnectionRow extends StatelessWidget {
  const _TestConnectionRow({
    required this.status,
    required this.error,
    required this.onPressed,
  });

  final _TestStatus status;
  final String? error;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final s = context.saqqar;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GhostButton(
          label: status == _TestStatus.running
              ? tr.testingConnection
              : tr.testConnection,
          icon: AppIcons.shieldCheck,
          onPressed: onPressed,
        ),
        if (status != _TestStatus.idle) ...[
          const SizedBox(height: AppSpacing.s8),
          _TestBadge(
            status: status,
            // For `failed`, render "Connection failed: <reason>". The
            // server's `error` is developer-facing English; [testConnectionError]
            // maps the common cases to the active locale and falls back to
            // the raw text only for unknown errors.
            text: switch (status) {
              _TestStatus.running => tr.testingConnection,
              _TestStatus.ok => tr.testConnectionOk,
              _TestStatus.failed =>
                error == null
                    ? tr.testConnectionFailed
                    : '${tr.testConnectionFailed}: ${tr.testConnectionError(error!)}',
              _TestStatus.idle => '',
            },
            color: switch (status) {
              _TestStatus.ok => s.success,
              _TestStatus.failed => s.danger,
              _ => s.muted,
            },
          ),
        ],
      ],
    );
  }
}

class _TestBadge extends StatelessWidget {
  const _TestBadge({
    required this.status,
    required this.text,
    required this.color,
  });

  final _TestStatus status;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s10,
        vertical: AppSpacing.s8,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppAlphas.a10),
        borderRadius: AppRadius.tightR,
        border: Border.all(color: color.withValues(alpha: AppAlphas.a35)),
      ),
      child: Row(
        children: [
          if (status == _TestStatus.running)
            SizedBox(
              width: AppControlSizes.spinnerDense,
              height: AppControlSizes.spinnerDense,
              child: CircularProgressIndicator(
                strokeWidth: AppStrokeWidths.spinnerThin,
                color: color,
              ),
            )
          else
            Icon(
              status == _TestStatus.ok ? AppIcons.success : AppIcons.error,
              color: color,
              size: AppIconSizes.small,
            ),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Text(
              text,
              style: context.text.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: AppFontSizes.footnote,
                height: AppLineHeights.label,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
