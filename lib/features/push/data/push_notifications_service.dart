import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/routing/route_names.dart';
import 'devices_api.dart';

/// Background isolate handler — MUST be a top-level / static function with the
/// `@pragma('vm:entry-point')` annotation. FCM spins up a fresh isolate to
/// deliver messages while the app is terminated; registering this is what
/// lets that happen. The OS already renders the `notification` block in the
/// background, so there's nothing to draw here — it exists so data is
/// delivered + the tap path works on a cold launch.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // No-op: the OS shows the notification; tap routing is handled by
  // `getInitialMessage` / `onMessageOpenedApp` once the app is running.
}

/// Android notification channels — ids MUST match
/// docs/PUSH_NOTIFICATIONS_BACKEND.md §3 (`android.notification.channel_id`).
const _approvalsChannel = AndroidNotificationChannel(
  'saqqar_approvals',
  'Approvals',
  description: 'Actions that are waiting for your approval',
  importance: Importance.high,
);
const _updatesChannel = AndroidNotificationChannel(
  'saqqar_updates',
  'Updates',
  description: 'Finished tasks and ready reports',
  importance: Importance.defaultImportance,
);

/// Wires Firebase Cloud Messaging into the app: permission, token
/// registration (via [DevicesApi]), foreground display (via
/// flutter_local_notifications — FCM only auto-shows in background/
/// terminated), and tap routing to the right conversation.
///
/// Lifecycle is auth-driven: [start] once the user is authenticated,
/// [stop] on logout (which also unregisters the device server-side so a
/// signed-out phone stops receiving that user's pushes).
class PushNotificationsService {
  PushNotificationsService(this._devices);

  static const _tag = 'PushNotificationsService';

  final DevicesApi _devices;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  final List<StreamSubscription<dynamic>> _subs = [];
  bool _started = false;

  /// The server-side device row id from the last successful register — kept
  /// so [stop] can revoke exactly this device on logout.
  String? _deviceId;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      final messaging = FirebaseMessaging.instance;
      // iOS shows the system prompt here; Android 13+ shows the runtime
      // POST_NOTIFICATIONS prompt. A denial just means no notifications —
      // token registration still proceeds (the user can enable later).
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      await _initLocalNotifications();

      final token = await messaging.getToken();
      if (token != null) await _registerToken(token);

      _subs.add(messaging.onTokenRefresh.listen(_registerToken));
      _subs.add(FirebaseMessaging.onMessage.listen(_onForegroundMessage));
      _subs.add(FirebaseMessaging.onMessageOpenedApp.listen(_routeFromMessage));

      // Cold launch FROM a notification tap (terminated state).
      final initial = await messaging.getInitialMessage();
      if (initial != null) _routeFromMessage(initial);
    } catch (e, st) {
      AppLogger.warn(_tag, 'start() failed', error: e, stackTrace: st);
    }
  }

  /// Tear down listeners and unregister this device server-side. Called on
  /// logout so the next user (or a signed-out device) gets no pushes.
  Future<void> stop() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    _started = false;
    final id = _deviceId;
    _deviceId = null;
    if (id != null) {
      try {
        await _devices.revoke(id);
      } catch (e, st) {
        AppLogger.warn(_tag, 'device revoke failed', error: e, stackTrace: st);
      }
    }
  }

  Future<void> _registerToken(String token) async {
    try {
      final res = await _devices.register(
        platform: Platform.isIOS ? DevicePlatform.ios : DevicePlatform.android,
        token: token,
      );
      _deviceId = res.device.id;
      AppLogger.info(_tag, 'device registered (created=${res.created})');
    } catch (e, st) {
      AppLogger.warn(_tag, 'token register failed', error: e, stackTrace: st);
    }
  }

  Future<void> _initLocalNotifications() async {
    const init = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      // We already asked for permission via FirebaseMessaging — don't prompt
      // twice here.
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _local.initialize(
      init,
      onDidReceiveNotificationResponse: (response) {
        final convId = response.payload;
        if (convId != null && convId.isNotEmpty) _openConversation(convId);
      },
    );
    final android = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(_approvalsChannel);
    await android?.createNotificationChannel(_updatesChannel);
  }

  /// Foreground messages aren't auto-displayed by FCM on Android, so mirror
  /// them through flutter_local_notifications. Carries `conversation_id` as
  /// the payload so a tap routes correctly.
  void _onForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return; // data-only — nothing user-facing.
    final isApproval = message.data['type'] == 'approval_required';
    final channel = isApproval ? _approvalsChannel : _updatesChannel;
    _local.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: channel.importance,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: message.data['conversation_id'] as String?,
    );
  }

  void _routeFromMessage(RemoteMessage message) {
    final convId = message.data['conversation_id'] as String?;
    if (convId != null && convId.isNotEmpty) _openConversation(convId);
  }

  /// Routes via the global [appRouter] — the tap handler fires outside the
  /// widget tree, so there's no `BuildContext` to use `context.go` with.
  void _openConversation(String conversationId) {
    final router = appRouter;
    if (router == null) {
      AppLogger.debug(_tag, 'router not ready; dropping open($conversationId)');
      return;
    }
    router.go(RouteNames.chatPath(conversationId));
  }
}
