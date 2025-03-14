import 'package:objectbox/objectbox.dart';
import 'package:things/src/extra_data.dart';

@Entity()
class Thing {
  Thing({
    required this.content,
    required this.createdAt,
    this.done = false,
    this.tags = const [],
    double? value,
    ExtraData? extraData,
  })  : _value = value,
        _extraData = extraData ?? ExtraData();

  @Id()
  int id = 0;

  int rank = 0;

  // Main property of a thing is it's content
  String content;

  // When it was created;
  @Property(type: PropertyType.date)
  DateTime createdAt;

  // Other optional attributes
  // Marks when thing is done or not
  bool done;

  // Value in money units
  double? _value;

  set value(double? value) => _value = value;

  // Children of the thing
  final children = ToMany<Thing>();

  // Conversely, parents of the thing
  @Backlink('children')
  final parents = ToMany<Thing>();

  // Internal purposes, to tag things from the system
  List<String> tags = [];

  // value appears as either internal or calculated property
  double? get value {
    if (_value != null) return _value;
    if (children.isEmpty) return null;
    var allNull = true;
    var accumulatedValue = 0.0;
    for (final child in children) {
      if (child.value != null) {
        allNull = false;
        accumulatedValue += child.value!;
      }
    }
    if (allNull) return null;
    return accumulatedValue;
  }

  // Extra data
  ExtraData _extraData;

  ExtraData get extraData => _extraData;

  set extraData(ExtraData extraData) {
    _extraData = extraData;
  }

  Thing copyWith({
    String? content,
    DateTime? createdAt,
    bool? done,
    double? value,
    ExtraData? extraData,
  }) {
    return Thing(
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      done: done ?? this.done,
      value: value ?? _value,
      extraData: extraData ?? _extraData,
    );
  }
}
