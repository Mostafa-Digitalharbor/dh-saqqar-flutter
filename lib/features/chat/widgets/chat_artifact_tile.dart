import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../demo/saqqar_demo_data.dart';

/// One artifact row used inside the chat "Artifacts" sheet — surface card +
/// cyan icon plate + download trailing button.
class ChatArtifactTile extends StatelessWidget {
  const ChatArtifactTile({
    super.key,
    required this.artifact,
    required this.onOpen,
  });

  final DemoArtifact artifact;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: s.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: s.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: s.brandCyan.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(AppIcons.file, color: s.brandCyan, size: 18),
        ),
        title: Text(artifact.name),
        subtitle: Text(
          context.tr.artifactMeta(
            artifact.kind,
            artifact.size,
            artifact.createdLabel,
          ),
        ),
        trailing: IconButton(
          tooltip: context.tr.download,
          onPressed: onOpen,
          icon: Icon(AppIcons.download, color: s.brandCyan),
        ),
      ),
    );
  }
}
