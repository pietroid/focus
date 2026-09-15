import 'package:equatable/equatable.dart';

/// {@template overlay}
/// A user-created overlay placed on top of a PDF source.
/// {@endtemplate}
class Overlay extends Equatable {
  /// {@macro overlay}
  const Overlay({
    required this.id,
    required this.x,
    required this.y,
    required this.text,
    required this.color,
    required this.createdAt,
  });

  /// Creates an [Overlay] from a JSON map.
  factory Overlay.fromJson(Map<String, dynamic> json) {
    return Overlay(
      id: json['id'] as String? ?? '',
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
      text: json['text'] as String? ?? '',
      color: json['color'] as String? ?? '#FF0000',
      createdAt: DateTime.parse(json['createdAt'] as String? ?? ''),
    );
  }

  /// Unique identifier of the overlay.
  final String id;

  /// Horizontal position of the overlay in PDF viewer coordinates.
  final double x;

  /// Vertical position of the overlay in PDF viewer coordinates.
  final double y;

  /// Text displayed by the overlay.
  final String text;

  /// Color of the overlay text, as a hex string.
  final String color;

  /// Date and time when the overlay was created.
  final DateTime createdAt;

  /// Converts this [Overlay] into a JSON map.
  Map<String, dynamic> toJson() => {
        'id': id,
        'x': x,
        'y': y,
        'text': text,
        'color': color,
        'createdAt': createdAt.toIso8601String(),
      };

  @override
  List<Object?> get props => [id, x, y, text, color, createdAt];
}
