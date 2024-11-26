import 'package:objectbox/objectbox.dart';

@Entity()
class Note {
  Note({
    required this.description,
    required this.createdAt,
  });

  @Id()
  int id = 0;

  String description;

  @Property(type: PropertyType.date)
  DateTime createdAt;
}
