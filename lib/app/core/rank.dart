import 'package:focus/app/core/thing.dart';
import 'package:objectbox/objectbox.dart';

@Entity()
class RankedThing {
  RankedThing({
    required this.order,
  });

  @Id()
  int id = 0;

  final int order;
  final thing = ToOne<Thing>();
}
