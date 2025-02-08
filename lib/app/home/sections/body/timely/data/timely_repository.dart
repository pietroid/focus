import 'package:focus/app/common_infrastructure/data/object_box.dart';
import 'package:focus/app/thing/data/initializer.dart';
import 'package:focus/app/thing/data/thing.dart';
import 'package:focus/app/common_infrastructure/data/domain_data.dart';
import 'package:focus/app/common_infrastructure/data/streamed_data_source.dart';
import 'package:focus/objectbox.g.dart';
import 'package:rxdart/subjects.dart';

class TimelyRepository {
  TimelyRepository({
    required this.box,
  });

  ObjectBox box;

  BehaviorSubject<List<Thing>> get stream {
    QueryBuilder<Thing> query() => box.store.box<Thing>().query(
          Thing_.tags
              .containsElement(todaySectionTag)
              .or(Thing_.tags.containsElement(nowSectionTag)),
        );

    return SubjectQueryBuilder<Thing>(
      query: query,
      forEachMap: (thing) {
        //haven't found a better way to sort the children via query
        thing.children.sort((a, b) => a.rank.compareTo(b.rank));
        thing.children.applyToDb();
        return thing;
      },
    ).behaviorSubject;
  }
}
