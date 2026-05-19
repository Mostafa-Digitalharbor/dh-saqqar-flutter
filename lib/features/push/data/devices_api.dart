import 'package:flutter/foundation.dart';

import 'package:dio/dio.dart';

import '../../../core/network/api_endpoints.dart';

enum DevicePlatform {
  ios('ios'),
  android('android');

  const DevicePlatform(this.wire);
  final String wire;

  static DevicePlatform fromWire(String? value) {
    return value == 'android' ? DevicePlatform.android : DevicePlatform.ios;
  }
}

/// Registered push device (SAQQAR_MOBILE_API.md §12). The raw push token
/// is never returned by the server — only [tokenPreview] (first 12 chars
/// + ellipsis) so we can show the user "AAAA-fake-ap…" in a devices list.
@immutable
class DeviceRow {
  const DeviceRow({
    required this.id,
    required this.platform,
    required this.tokenPreview,
    this.appVersion,
    this.lastSeenAt,
    this.createdAt,
  });

  final String id;
  final DevicePlatform platform;
  final String tokenPreview;
  final String? appVersion;
  final DateTime? lastSeenAt;
  final DateTime? createdAt;

  factory DeviceRow.fromJson(Map<String, dynamic> json) {
    return DeviceRow(
      id: json['id'] as String,
      platform: DevicePlatform.fromWire(json['platform'] as String?),
      tokenPreview: json['token_preview'] as String? ?? '',
      appVersion: json['app_version'] as String?,
      lastSeenAt: _parseDate(json['last_seen_at']),
      createdAt: _parseDate(json['created_at']),
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value)?.toLocal();
    }
    return null;
  }
}

/// Repository for push-token registration.
///
/// Mobile calls [register] once after the user grants the OS permission
/// prompt, then again on each app launch (re-sending the same token
/// refreshes `last_seen_at` and re-binds the row to the calling user — so
/// account switching on the same device is handled).
class DevicesApi {
  DevicesApi(this._dio);

  final Dio _dio;

  /// `GET /api/v1/devices/` — list the caller's registered devices.
  Future<List<DeviceRow>> list() async {
    final res = await _dio.get<Map<String, dynamic>>(ApiEndpoints.devices);
    return (res.data!['devices'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .map(DeviceRow.fromJson)
        .toList();
  }

  /// `POST /api/v1/devices/` — upsert by token. Returns the row plus a
  /// `created` flag (true when this token was newly registered, false on
  /// the refresh path).
  Future<({DeviceRow device, bool created})> register({
    required DevicePlatform platform,
    required String token,
    String? appVersion,
  }) async {
    final body = <String, dynamic>{
      'platform': platform.wire,
      'token': token,
      if (appVersion != null) 'app_version': appVersion,
    };
    final res = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.devices,
      data: body,
    );
    return (
      device: DeviceRow.fromJson(res.data!['device'] as Map<String, dynamic>),
      created: res.data!['created'] as bool? ?? (res.statusCode == 201),
    );
  }

  /// `DELETE /api/v1/devices/<id>/` — revoke a single device. Idempotent —
  /// second call returns 404 (the caller can ignore that).
  Future<void> revoke(String id) async {
    await _dio.delete<void>(ApiEndpoints.deviceDetail(id));
  }
}

