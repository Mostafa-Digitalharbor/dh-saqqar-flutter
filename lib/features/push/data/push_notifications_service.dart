import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../core/app_build_info.dart';
import '../../../core/i18n/app_strings.dart';
import '../../../core/i18n/platform_strings.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/routing/route_names.dart';
import '../../notifications/data/notifications_store.dart';
import 'devices_api.dart';

/// Maps an FCM message into the inbox record shape. Top-level so the
/// background isolate handler can reuse it.
AppNotification appNotificationFrom(RemoteMessage m) {
  final n = m.notification;
  return AppNotification(
    // Prefer FCM's own message id. When it's absent, derive a STABLE id from
    // the message content instead of a wall-clock timestamp: the same push is
    // recorded from up to three code paths (foreground `onMessage`, a tap via
    // `onMessageOpenedApp`, and the background isolate), and a time-based id
    // would differ between them → the inbox would show the same notification
    // two or three times. A content hash collapses those to one row while
    // still separating genuinely different notifications.
    id: m.messageId ?? _syntheticNotificationId(m),
    type: (m.data['type'] as String?) ?? '',
    title: n?.title ?? '',
    body: n?.body ?? '',
    receivedAt: DateTime.now(),
    conversationId: m.data['conversation_id'] as String?,
  );
}

/// Stable fallback id for a push with no `messageId`, built from the fields
/// that identify it (type + conversation + title + body). Deterministic, so
/// every delivery path derives the same id and the inbox dedupe works.
String _syntheticNotificationId(RemoteMessage m) {
  final n = m.notification;
  final basis = [
    m.data['type'] ?? '',
    m.data['conversation_id'] ?? '',
    n?.title ?? '',
    n?.body ?? '',
  ].join('');
  return 'syn:${basis.hashCode}';
}

/// Background isolate handler — MUST be a top-level / static function with the
/// `@pragma('vm:entry-point')` annotation. FCM spins up a fresh isolate to
/// deliver messages while the app is terminated; registering this is what
/// lets that happen. The OS already renders the `notification` block in the
/// background, so there's nothing to draw here — it exists so data is
/// delivered + the tap path works on a cold launch.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // The OS shows the notification block itself; tap routing is handled by
  // `getInitialMessage` / `onMessageOpenedApp` once the app runs. We DO
  // persist it to the inbox here (SharedPreferences, isolate-safe) so a
  // notification the user never taps still shows up in the in-app bell.
  if (message.notification != null) {
    await NotificationsStore.appendToPrefs(appNotificationFrom(message));
  }
}

/// Android notification channels — ids MUST match
/// docs/PUSH_NOTIFICATIONS_BACKEND.md §3 (`android.notification.channel_id`).
///
/// The ids are a technical contract with the backend and never change. The
/// name/description are the opposite: Android renders them to the user in
/// system Settings, so they resolve through i18n rather than being pinned
/// to English. There's no `BuildContext` out here — see [PlatformStrings].
///
/// Android re-reads name/description when a channel is re-created under an
/// existing id, so [PushNotificationsService.start] refreshes them. A locale
/// change therefore lands on the next `start()` (i.e. next launch or
/// sign-in), not instantly — the channel is a system-owned surface the app
/// can't repaint on demand.
AndroidNotificationChannel _approvalsChannel(AppStrings tr) =>
    AndroidNotificationChannel(
      'saqqar_approvals',
      tr.pushChannelApprovalsName,
      description: tr.pushChannelApprovalsDescription,
      importance: Importance.high,
    );

AndroidNotificationChannel _updatesChannel(AppStrings tr) =>
    AndroidNotificationChannel(
      'saqqar_updates',
      tr.pushChannelUpdatesName,
      description: tr.pushChannelUpdatesDescription,
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
  PushNotificationsService(this._devices, this._store, this._platformStrings);

  static const _tag = 'PushNotificationsService';

  final DevicesApi _devices;
  final NotificationsStore _store;

  /// Resolves notification copy for the OS-facing surfaces below, which run
  /// with no `BuildContext` and would otherwise be pinned to English.
  final PlatformStrings _platformStrings;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  final List<StreamSubscription<dynamic>> _subs = [];
  bool _started = false;

  /// Bumped by [stop]. [start] captures the value on entry and bails at each
  /// async checkpoint if it changed — so a fast authenticated→unauthenticated
  /// flip can't let an in-flight [start] re-register the device (or add
  /// listeners) AFTER [stop] already revoked it for a signed-out user.
  int _generation = 0;

  /// The server-side device row id from the last successful register — kept
  /// so [stop] can revoke exactly this device on logout.
  String? _deviceId;

  /// The app's current UI language (`en`/`ar`) sent with the token so the
  /// backend localizes the OS-rendered notification text. Updated live via
  /// [updateLocale] when the user switches language.
  String? _localeCode;

  Future<void> start({String? localeCode}) async {
    _localeCode = localeCode;
    if (_started) return;
    _started = true;
    final gen = _generation;
    try {
      final messaging = FirebaseMessaging.instance;
      // iOS shows the system prompt here; Android 13+ shows the runtime
      // POST_NOTIFICATIONS prompt. A denial just means no notifications —
      // token registration still proceeds (the user can enable later).
      final settings =
          await messaging.requestPermission(alert: true, badge: true, sound: true);
      // Log the permission outcome. On iOS a `denied`/`notDetermined` here means
      // nothing will ever be delivered (notifications refused, or the prompt
      // never ran) — a top cause of "push doesn't work" that is otherwise
      // invisible. Pairs with the `APNs token`/`FCM token` lines below.
      AppLogger.info(
        _tag,
        'notification permission = ${settings.authorizationStatus} '
        '(alert=${settings.alert}, badge=${settings.badge})',
      );
      // iOS suppresses the banner for the app that is CURRENTLY FRONTMOST
      // unless it is told otherwise — firebase_messaging's notification-centre
      // delegate returns empty presentation options by default. Without this
      // call the push still arrives, it just never renders: the symptom is
      // "notifications only show when the app is closed" (and, on a paired
      // Apple Watch, "it shows on the watch but not the phone" — the watch is
      // a separate device, so the frontmost-app rule does not apply there).
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      await _initLocalNotifications();
      // If stop() ran while we were awaiting the prompts above, abort before
      // we register the device or attach any listeners — otherwise a
      // signed-out phone gets re-registered for the previous user's pushes.
      if (gen != _generation) return;

      final token = await _getTokenForRegistration(messaging);
      if (gen != _generation) return;
      // Debug-only (AppLogger is a no-op in release): surfaces the token so it
      // can be pasted into Firebase Console → "Send test message" to verify
      // delivery independently of the backend.
      AppLogger.info(_tag, 'FCM token = $token');
      if (token != null) {
        await _registerToken(token);
      } else {
        AppLogger.warn(_tag, 'FCM token unavailable; device not registered');
      }
      if (gen != _generation) return;

      _subs.add(messaging.onTokenRefresh.listen(_registerToken));
      _subs.add(FirebaseMessaging.onMessage.listen(_onForegroundMessage));
      _subs.add(FirebaseMessaging.onMessageOpenedApp.listen(_routeFromMessage));

      // Cold launch FROM a notification tap (terminated state).
      final initial = await messaging.getInitialMessage();
      if (gen != _generation) return;
      if (initial != null) _routeFromMessage(initial);
    } catch (e, st) {
      AppLogger.warn(_tag, 'start() failed', error: e, stackTrace: st);
    }
  }

  /// Tear down listeners and unregister this device server-side. Called on
  /// logout so the next user (or a signed-out device) gets no pushes.
  Future<void> stop() async {
    // Invalidate any in-flight start() so it can't re-register this device
    // after we revoke it below.
    _generation++;
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

  /// Re-registers the current token with a new UI [localeCode] when the user
  /// switches language mid-session, so the next notification's title/body
  /// arrives in the right language. No-op until [start] has run / on no change.
  Future<void> updateLocale(String? localeCode) async {
    if (!_started || localeCode == _localeCode) return;
    _localeCode = localeCode;
    try {
      final messaging = FirebaseMessaging.instance;
      final token = await _getTokenForRegistration(messaging);
      if (token != null) await _registerToken(token);
    } catch (e, st) {
      AppLogger.warn(_tag, 'updateLocale failed', error: e, stackTrace: st);
    }
  }

  // iOS ONLY: FCM can't mint a token until APNs has handed the app its
  // device token (this is gated behind the swizzled
  // `didRegisterForRemoteNotifications` callback). If getToken() runs before
  // that, it returns null — or throws `apns-token-not-set` — and the device
  // is never registered. That is the classic "push works on Android but not
  // on iOS" symptom, so this is used everywhere a token is needed (initial
  // registration in [start] and re-registration in [updateLocale]) rather
  // than calling `messaging.getToken()` directly.
  Future<String?> _getTokenForRegistration(FirebaseMessaging messaging) async {
    if (Platform.isIOS) {
      final apnsToken = await _awaitApnsToken(messaging);
      if (apnsToken == null) {
        AppLogger.warn(
          _tag,
          'APNs token still null after retries — iOS push cannot work. '
          'Check on a real device (the simulator has no APNs): Push '
          'Notifications capability, the aps-environment entitlement, and '
          'that an APNs auth key is uploaded for this app in Firebase.',
        );
        return null;
      }
      AppLogger.info(_tag, 'APNs token = $apnsToken');
    }
    return messaging.getToken();
  }

  /// Polls for the iOS APNs device token. Firebase hands it over
  /// asynchronously once the OS has granted notification permission and
  /// registered the app with APNs; until it arrives, the FCM `getToken()`
  /// can't be minted. Retries with a short backoff instead of giving up on
  /// the first null (the token typically lands within a second or two on a
  /// real device, and never on the simulator).
  Future<String?> _awaitApnsToken(FirebaseMessaging messaging) async {
    for (var attempt = 0; attempt < 20; attempt++) {
      try {
        final apns = await messaging.getAPNSToken();
        if (apns != null && apns.isNotEmpty) return apns;
      } catch (e, st) {
        AppLogger.warn(_tag, 'getAPNSToken attempt $attempt failed',
            error: e, stackTrace: st);
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    return null;
  }

  Future<void> _registerToken(String token) async {
    try {
      // Without this the server stores "" and the Devices screen — whose
      // whole job is "which build is this phone on?" — showed every row as
      // a bare "Android". `label` is empty only when the PackageInfo read
      // failed, and `register` omits the field entirely in that case rather
      // than writing a blank over a previously-known value.
      final build = AppBuildInfo.label;
      final res = await _devices.register(
        platform: Platform.isIOS ? DevicePlatform.ios : DevicePlatform.android,
        token: token,
        appVersion: build.isEmpty ? null : build,
        locale: _localeCode,
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
    final android = _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    // Explicitly request the Android 13+ POST_NOTIFICATIONS runtime permission.
    // FirebaseMessaging.requestPermission alone doesn't reliably surface the
    // system dialog on every OEM skin (e.g. MIUI/HyperOS) — this one does.
    // NOTE: Android only shows the dialog ONCE; if the user previously denied
    // it, this returns false silently and they must enable it in Settings.
    await android?.requestNotificationsPermission();
    final tr = _platformStrings.strings;
    await android?.createNotificationChannel(_approvalsChannel(tr));
    await android?.createNotificationChannel(_updatesChannel(tr));
  }

  /// Foreground messages aren't auto-displayed by FCM on Android, so mirror
  /// them through flutter_local_notifications. Carries `conversation_id` as
  /// the payload so a tap routes correctly.
  void _onForegroundMessage(RemoteMessage message) {
    // Proves DELIVERY independently of DISPLAY. Without this, a push that FCM
    // delivered but iOS chose not to banner (app in foreground, Focus mode)
    // is indistinguishable from one that never arrived — the two have opposite
    // fixes. If this line prints, the whole Firebase↔APNs chain is working.
    AppLogger.info(
      _tag,
      '📩 push RECEIVED (foreground) — id=${message.messageId} '
      'title=${message.notification?.title} body=${message.notification?.body} '
      'data=${message.data}',
    );
    final notification = message.notification;
    if (notification == null) return; // data-only — nothing user-facing.
    // Keep it in the in-app inbox so the user can review it later.
    _store.add(appNotificationFrom(message));
    // iOS now presents the FCM notification itself (see the
    // setForegroundNotificationPresentationOptions call in start()), so
    // mirroring it here as well would banner the same push TWICE. Android
    // still needs the mirror — FCM never auto-displays there in the
    // foreground.
    if (Platform.isIOS) return;
    final isApproval = message.data['type'] == 'approval_required';
    final tr = _platformStrings.strings;
    final channel = isApproval ? _approvalsChannel(tr) : _updatesChannel(tr);
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
    AppLogger.info(
      _tag,
      '📩 push OPENED (tap) — id=${message.messageId} data=${message.data}',
    );
    // A tapped notification (from background/terminated) wasn't captured by
    // onMessage — record it so it lands in the inbox too. Deduped by id.
    if (message.notification != null) _store.add(appNotificationFrom(message));
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
