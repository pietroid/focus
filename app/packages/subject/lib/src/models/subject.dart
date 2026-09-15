import 'package:equatable/equatable.dart';
import 'package:subject/src/models/source.dart';

/// {@template subject}
/// A study subject created by a user.
/// {@endtemplate}
class Subject extends Equatable {
  /// {@macro subject}
  const Subject({
    required this.id,
    required this.name,
    required this.createdAt,
    this.sources = const [],
    this.lastOpenedSource,
  });

  /// Creates a [Subject] from a JSON map.
  factory Subject.fromJson(Map<String, dynamic> json) {
    final rawSources = json['sources'] as List<dynamic>? ?? [];

    return Subject(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String? ?? ''),
      sources: rawSources
          .map((source) => Source.fromJson(source as Map<String, dynamic>))
          .toList(),
      lastOpenedSource: json['lastOpenedSource'] as String?,
    );
  }

  /// Unique identifier of the subject.
  final String id;

  /// Display name of the subject.
  final String name;

  /// Date and time when the subject was created.
  final DateTime createdAt;

  /// List of PDF sources attached to this subject.
  final List<Source> sources;

  /// Identifier of the most recently opened source, if any.
  final String? lastOpenedSource;

  /// Converts this [Subject] into a JSON map.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'sources': sources.map((source) => source.toJson()).toList(),
        'lastOpenedSource': lastOpenedSource,
      };

  /// Creates a copy of this subject with the given fields replaced.
  Subject copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    List<Source>? sources,
    String? lastOpenedSource,
  }) {
    return Subject(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      sources: sources ?? this.sources,
      lastOpenedSource: lastOpenedSource ?? this.lastOpenedSource,
    );
  }

  @override
  List<Object?> get props => [id, name, createdAt, sources, lastOpenedSource];
}
