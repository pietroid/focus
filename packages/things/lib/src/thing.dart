import 'package:objectbox/objectbox.dart';

@Entity()
class Thing {
  Thing({
    required this.content,
    required this.createdAt,
    this.done = false,
    this.tags = const [],
    double? value,
    Duration? this.duration,
    DateTime? this.startTime,
  }) : _value = value;

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

  // Duration of the thing
  @Transient()
  Duration? duration;

  // Start time
  @Property(type: PropertyType.date)
  DateTime? startTime;

  // End time
  @Transient()
  DateTime? get endTime => startTime?.add(duration ?? Duration.zero);

  // dbDuration
  int? get dbDuration => duration?.inMilliseconds;

  set dbDuration(int? dbDuration) {
    if (dbDuration != null) {
      duration = Duration(milliseconds: dbDuration);
    }
  }

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

  Thing copyWith({
    String? content,
    DateTime? createdAt,
    bool? done,
    double? value,
  }) {
    return Thing(
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      done: done ?? this.done,
      value: value ?? _value,
    );
  }
}
