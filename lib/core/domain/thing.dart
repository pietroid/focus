import 'package:objectbox/objectbox.dart';

@Entity()
class Thing {
  Thing({
    required this.content,
    required this.createdAt,
    required this.done,
  });

  @Id()
  int id = 0;

  String content;

  @Property(type: PropertyType.date)
  DateTime createdAt;

  // TODO: maybe add this to a generic field
  bool done;
}
