import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One received push notification, kept for the in-app inbox so the user can
/// review notifications they got earlier (the OS shade clears them).
@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.receivedAt,
    this.conversationId,
    this.read = false,
  });

  final String id;

  /// `approval_required` | `run_complete` | `artifact_ready` | `quota_warning`
  /// (or empty for anything unrecognised). Drives the row icon + accent.
  final String type;
  final String title;
  final String body;
  final DateTime receivedAt;

  /// The chat this notification belongs to — tapping the row opens it.
  final String? conversationId;
  final bool read;

  AppNotification copyWith({bool? read}) => AppNotification(
        id: id,
        type: type,
        title: title,
        body: body,
        receivedAt: receivedAt,
        conversationId: conversationId,
        read: read ?? this.read,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'title': title,
        'body': body,
        'received_at': receivedAt.toUtc().toIso8601String(),
        if (conversationId != null) 'conversation_id': conversationId,
        'read': read,
      };

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      receivedAt: DateTime.tryParse(json['received_at'] as String? ?? '')
              ?.toLocal() ??
          DateTime.now(),
      conversationId: json['conversation_id'] as String?,
      read: json['read'] as bool? ?? false,
    );
  }
}

/// Persistent, in-memory-mirrored inbox of received notifications.
///
/// A [ChangeNotifier] (provided app-wide) so the header bell's unread dot and
/// the inbox screen rebuild live when a foreground notification lands. Backed
/// by SharedPreferences under [_key] so it survives restarts AND so the FCM
/// **background isolate** can append via the static [appendToPrefs] (it has no
/// access to this instance) — the instance re-reads on [reload].
class NotificationsStore extends ChangeNotifier {
  NotificationsStore(this._prefs) {
    _items = _readFrom(_prefs);
  }

  static const _key = 'saqqar.notifications.inbox.v1';
  static const _cap = 50;

  final SharedPreferences _prefs;
  List<AppNotification> _items = const [];

  List<AppNotification> get items => List.unmodifiable(_items);
  int get unreadCount => _items.where((n) => !n.read).length;
  bool get hasUnread => unreadCount > 0;

  /// Add a freshly-received notification (foreground / tapped). Deduped by id,
  /// newest first, capped.
  void add(AppNotification n) {
    _items = [n, ..._items.where((e) => e.id != n.id)];
    if (_items.length > _cap) _items = _items.sublist(0, _cap);
    _persist();
    notifyListeners();
  }

  void markAllRead() {
    if (_items.every((n) => n.read)) return;
    _items = [for (final n in _items) n.copyWith(read: true)];
    _persist();
    notifyListeners();
  }

  void remove(String id) {
    final next = _items.where((n) => n.id != id).toList();
    if (next.length == _items.length) return;
    _items = next;
    _persist();
    notifyListeners();
  }

  void clear() {
    if (_items.isEmpty) return;
    _items = const [];
    _persist();
    notifyListeners();
  }

  /// Re-read from disk — picks up entries the FCM background isolate wrote
  /// while the app was backgrounded. Call on resume / when the inbox opens.
  void reload() {
    _items = _readFrom(_prefs);
    notifyListeners();
  }

  void _persist() {
    try {
      _prefs.setString(
        _key,
        jsonEncode(_items.map((n) => n.toJson()).toList()),
      );
    } catch (_) {
      // Best-effort — a prefs hiccup must never break the UI.
    }
  }

  static List<AppNotification> _readFrom(SharedPreferences prefs) {
    try {
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return const [];
      return (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>()
          .map(AppNotification.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Append from a context with NO store instance (the FCM background
  /// isolate). Reads → prepends → caps → writes the same key. The live
  /// instance surfaces it on the next [reload].
  static Future<void> appendToPrefs(AppNotification n) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _readFrom(prefs);
      final next = [n, ...list.where((e) => e.id != n.id)];
      final capped = next.length > _cap ? next.sublist(0, _cap) : next;
      await prefs.setString(
        _key,
        jsonEncode(capped.map((e) => e.toJson()).toList()),
      );
    } catch (_) {
      // ignore
    }
  }

  /// Wipe the inbox (sign-out / account deletion).
  Future<void> clearPersisted() async {
    _items = const [];
    try {
      await _prefs.remove(_key);
    } catch (_) {}
    notifyListeners();
  }
}
