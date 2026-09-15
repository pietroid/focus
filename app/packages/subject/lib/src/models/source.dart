import 'package:equatable/equatable.dart';
import 'package:subject/src/models/overlay.dart';

/// {@template source}
/// A PDF source attached to a subject.
/// {@endtemplate}
class Source extends Equatable {
  /// {@macro source}
  const Source({
    required this.id,
    required this.url,
    required this.name,
    required this.createdAt,
    this.overlays = const [],
  });

  /// Creates a [Source] from a JSON map.
  factory Source.fromJson(Map<String, dynamic> json) {
    final rawOverlays = json['overlays'] as List<dynamic>? ?? [];

    return Source(
      id: json['id'] as String? ?? '',
      url: json['url'] as String? ?? '',
      name: json['name'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String? ?? ''),
      overlays: rawOverlays
          .map((overlay) => Overlay.fromJson(overlay as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Unique identifier of the source.
  final String id;

  /// Public URL of the PDF.
  final String url;

  /// Display name of the source file.
  final String name;

  /// Date and time when the source was uploaded.
  final DateTime createdAt;

  /// User-created overlays placed on top of the PDF.
  final List<Overlay> overlays;

  /// Converts this [Source] into a JSON map.
  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'overlays': overlays.map((overlay) => overlay.toJson()).toList(),
      };

  /// Creates a copy of this source with the given fields replaced.
  Source copyWith({
    String? id,
    String? url,
    String? name,
    DateTime? createdAt,
    List<Overlay>? overlays,
  }) {
    return Source(
      id: id ?? this.id,
      url: url ?? this.url,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      overlays: overlays ?? this.overlays,
    );
  }

  @override
  List<Object?> get props => [id, url, name, createdAt, overlays];
}
