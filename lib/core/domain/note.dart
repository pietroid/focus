import 'package:objectbox/objectbox.dart';

@Entity()
class Note {
  Note({
    required this.content,
    required this.createdAt,
  });

  @Id()
  int id = 0;

  String content;

  @Property(type: PropertyType.date)
  DateTime createdAt;
}
