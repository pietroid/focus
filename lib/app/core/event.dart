import 'package:objectbox/objectbox.dart';

@Entity()
class Event {
  Event({
    required this.initialTime,
    required this.finalTime,
  });

  @Id()
  int id = 0;

  @Property(type: PropertyType.date)
  DateTime initialTime;

  @Property(type: PropertyType.date)
  DateTime finalTime;

  @Transient()
  Duration get duration => finalTime.difference(initialTime);
}
