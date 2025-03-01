import 'package:local_service/local_service.dart';

import 'package:rxdart/subjects.dart';
import 'package:things/things.dart';

class ContentRepository {
  ContentRepository({
    required this.box,
  });
  final ObjectBox box;

  BehaviorSubject<List<Thing>> stream({required int thingId}) {
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
