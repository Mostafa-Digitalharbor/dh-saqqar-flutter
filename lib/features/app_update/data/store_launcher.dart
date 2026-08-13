import 'package:url_launcher/url_launcher.dart';

import '../../../core/logging/app_logger.dart';

/// Opens the platform store listing for the update.
///
/// Shared by the blocking wall and the dismissible nudge so both treat a
/// failed launch identically — the blocking wall in particular must report
/// failure honestly rather than appear to have done something, since a user
/// standing in front of it with a dead button and no message has no way to
/// tell the app apart from frozen.
///
/// `externalApplication` (not `inAppBrowserView`): a Play/App Store URL opened
/// in an in-app webview shows a listing page with no working install button
/// on either platform. It has to hand off to the real store app.
Future<bool> openStoreListing(String rawUrl) async {
  final uri = Uri.tryParse(rawUrl);
  // The URL is server-supplied, so it can be blank, relative, or a scheme we
  // have no business launching. Only http(s) and the stores' own schemes are
  // ever legitimate here.
  if (uri == null || !uri.hasScheme || !uri.hasAuthority) return false;
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (error, stackTrace) {
    AppLogger.warn(
      'StoreLauncher',
      'store launch failed',
      error: error,
      stackTrace: stackTrace,
    );
    return false;
  }
}
