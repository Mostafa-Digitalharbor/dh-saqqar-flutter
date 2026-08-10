import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/code_plate.dart';
import '../data/artifact_models.dart';
import '../data/artifacts_api.dart';

/// Opens the artifact-details bottom sheet (API_MOBILE_NEW_ENDPOINTS.md
/// §4.4). Reads [ArtifactsApi] from the caller's context, so it works
/// anywhere the boot-scoped provider is in scope (e.g. the chat rail).
Future<void> showArtifactDetailsSheet(
  BuildContext context, {
  required String id,
  required String name,
}) {
  final api = context.read<ArtifactsApi>();
  final s = context.saqqar;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: s.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => ArtifactDetailsSheet(api: api, id: id, name: name),
  );
}

/// Fetches `GET /api/v1/artifacts/<id>/` and shows the artifact's metadata.
/// Takes its [api] explicitly so it renders in a widget test without a
/// provider tree.
class ArtifactDetailsSheet extends StatefulWidget {
  const ArtifactDetailsSheet({
    super.key,
    required this.api,
    required this.id,
    required this.name,
  });

  final ArtifactsApi api;
  final String id;
  final String name;

  @override
  State<ArtifactDetailsSheet> createState() => _ArtifactDetailsSheetState();
}

class _ArtifactDetailsSheetState extends State<ArtifactDetailsSheet> {
  Artifact? _artifact;
  Object? _failure;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _failure = null;
    });
    try {
      final artifact = await widget.api.detail(widget.id);
      if (!mounted) return;
      setState(() {
        _artifact = artifact;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _failure = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return SafeArea(
      // Scrollable, because a bottom sheet's height is the viewport's to
      // decide and this sheet's is the content's. In landscape (568×320) the
      // artifact name, the meta rows and the action buttons come to 2 px more
      // than the sheet is allowed to be, and a `Column(mainAxisSize: min)`
      // answers that by painting past its own edge — the download button ends
      // up under the screen with no way to reach it.
      //
      // `SingleChildScrollView` inside the sheet's bounded height sizes to the
      // content when it fits and scrolls when it does not, so the tall-phone
      // layout is pixel-identical to before.
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: s.border,
                  borderRadius: AppRadius.pillR,
                ),
              ),
            ),
            Text(
              context.tr.artifactDetailsTitle,
              style:
                  context.text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              widget.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall?.copyWith(color: s.muted),
            ),
            const SizedBox(height: 14),
            _buildBody(context),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final s = context.saqqar;
    if (_loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 2.4, color: s.muted),
        ),
      );
    }
    if (_failure != null) {
      return AppErrorState(
        message: ApiErrorMapper.message(context, _failure),
        onRetry: _fetch,
      );
    }
    final a = _artifact;
    if (a == null) return const SizedBox.shrink();
    // Show the real fields the detail endpoint returned, pretty-printed.
    final display = <String, dynamic>{
      'id': a.id,
      'name': a.name,
      'kind': a.kind,
      'mime_type': a.mimeType,
      'url': a.url,
      if (a.filePath != null) 'file_path': a.filePath,
      if (a.createdAt != null) 'created_at': a.createdAt!.toIso8601String(),
      'metadata': a.metadata,
    };
    final json = const JsonEncoder.withIndent('  ').convert(display);
    // Bounded height with vertical scroll; CodePlate adds horizontal scroll
    // for any single long value so nothing overflows the sheet.
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 340),
      child: SingleChildScrollView(
        child: CodePlate(text: json, accent: s.text),
      ),
    );
  }
}
