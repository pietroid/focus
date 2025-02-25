import 'package:local_service/local_service.dart';

import 'package:focus/app/thing/data/thing.dart';
import 'package:focus/objectbox.g.dart';
import 'package:rxdart/subjects.dart';

class ContentRepository {
  ContentRepository({
    required this.thingId,
    required this.box,
  });
  final int thingId;
  final ObjectBox box;

  BehaviorSubject<List<Thing>> get stream {
    return SubjectQueryBuilder<Thing>(
      query: () => box.store.box<Thing>().query(
            Thing_.id.equals(thingId),
          ),
      forEachMap: (thing) {
        //haven't found a better way to sort the children via query
        thing.children.sort((a, b) => a.rank.compareTo(b.rank));
        thing.children.applyToDb();
        return thing;
      },
    ).behaviorSubject;
  }
}
