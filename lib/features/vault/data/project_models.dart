import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

/// A deployment target (live / staging / dev) inside a Project. Owns up to
/// one credential per kind.
///
/// Schema mirror of SAQQAR_MOBILE_API.md §11 — the `environment` object
/// served both as a standalone resource and nested inside [Project] and the
/// conversation snapshot.
@immutable
class Environment extends Equatable {
  const Environment({
    required this.id,
    required this.name,
    required this.slug,
    required this.isLive,
    required this.readOnly,
    required this.autoApprove,
    required this.projectId,
    this.hasXmlrpc = false,
  });

  final String id;
  final String name;
  final String slug;

  /// Forces `autoApprove` off regardless of the stored value. Shows the
  /// LIVE badge in the UI.
  final bool isLive;

  /// Destructive Odoo writes / shell calls refuse with a clean error when
  /// this is true.
  final bool readOnly;

  /// Pre-approves writes at the env level. Ignored when [isLive] is true.
  final bool autoApprove;

  final String projectId;

  /// `has_xmlrpc` (Gap H) — whether this env already has Odoo XML-RPC
  /// credentials set. Drives the "set credentials first" prompt when the
  /// user binds an env that can't actually connect yet. Not all responses
  /// annotate this (defaults to false / unknown).
  final bool hasXmlrpc;

  factory Environment.fromJson(Map<String, dynamic> json) {
    return Environment(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      isLive: json['is_live'] as bool? ?? false,
      readOnly: json['read_only'] as bool? ?? false,
      autoApprove: json['auto_approve'] as bool? ?? false,
      projectId: json['project_id'] as String? ?? '',
      // Server annotates either `has_xmlrpc` (GET /projects/) or
      // `has_credential` (POST /projects/default/) — accept both.
      hasXmlrpc: (json['has_xmlrpc'] ?? json['has_credential']) as bool? ??
          false,
    );
  }

  /// Round-trip safe serialization for offline cache (SharedPreferences).
  /// Mirrors the server's snake_case so the cached blob is interchangeable
  /// with a fresh API response.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'is_live': isLive,
        'read_only': readOnly,
        'auto_approve': autoApprove,
        'project_id': projectId,
        'has_xmlrpc': hasXmlrpc,
      };

  Environment copyWith({
    String? name,
    bool? isLive,
    bool? readOnly,
    bool? autoApprove,
    bool? hasXmlrpc,
  }) {
    return Environment(
      id: id,
      name: name ?? this.name,
      slug: slug,
      isLive: isLive ?? this.isLive,
      readOnly: readOnly ?? this.readOnly,
      autoApprove: autoApprove ?? this.autoApprove,
      projectId: projectId,
      hasXmlrpc: hasXmlrpc ?? this.hasXmlrpc,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        slug,
        isLive,
        readOnly,
        autoApprove,
        projectId,
        hasXmlrpc,
      ];
}

/// Logical grouping of environments — typically one per client / customer.
@immutable
class Project extends Equatable {
  const Project({
    required this.id,
    required this.name,
    required this.slug,
    required this.environments,
  });

  final String id;
  final String name;
  final String slug;
  final List<Environment> environments;

  factory Project.fromJson(Map<String, dynamic> json) {
    final envs = (json['environments'] as List?)
            ?.cast<Map<String, dynamic>>()
            .map(Environment.fromJson)
            .toList() ??
        const <Environment>[];
    return Project(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      environments: envs,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'environments': environments.map((e) => e.toJson()).toList(),
      };

  @override
  List<Object?> get props => [id, name, slug, environments];
}
