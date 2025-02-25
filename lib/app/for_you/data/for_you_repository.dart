import 'package:focus/app/thing/data/initializer.dart';
import 'package:focus/app/thing/data/thing.dart';
import 'package:focus/objectbox.g.dart';
import 'package:local_service/local_service.dart';
import 'package:rxdart/subjects.dart';

class ForYouRepository {
  ForYouRepository({
    required this.box,
  });

  ObjectBox box;

  BehaviorSubject<List<Thing>> get stream {
    QueryBuilder<Thing> query() => box.store.box<Thing>().query(
          Thing_.tags.containsElement(forYouTag),
        );

    return SubjectQueryBuilder<Thing>(
      query: query,
      forEachMap: (thing) {
        //haven't found a better way to sort the children via query
        thing.children.sort((a, b) => a.rank.compareTo(b.rank));
        thing.children.applyToDb();
        for (final child in thing.children) {
          child.children.sort((a, b) => a.rank.compareTo(b.rank));
          child.children.applyToDb();
        }
        return thing;
      },
    ).behaviorSubject;
  }
}
