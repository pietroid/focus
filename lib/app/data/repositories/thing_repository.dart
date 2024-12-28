import 'package:cron/app/core/thing.dart';
import 'package:cron/app/data/object_box.dart';
import 'package:cron/app/data/streamed_data_source.dart';
import 'package:cron/objectbox.g.dart';
import 'package:rxdart/subjects.dart';

class ThingRepository {
  ThingRepository({
    required this.box,
  });
  final ObjectBox box;

  void addOrEditThing({
    required Thing thing,
  }) {
    box.store.box<Thing>().put(thing);
  }

  void setAsDone({
    required Thing thing,
  }) {
    thing.done = true;
    box.store.box<Thing>().put(thing);
  }

  void setAsUndone({
    required Thing thing,
  }) {
    thing.done = false;
    box.store.box<Thing>().put(thing);
  }

  BehaviorSubject<List<Thing>> watchTodoThings() {
    QueryBuilder<Thing> query() =>
        box.store.box<Thing>().query(Thing_.done.equals(false));
    return SubjectQueryBuilder<Thing>(
      query: query,
    ).behaviorSubject;
  }

  BehaviorSubject<List<Thing>> watchDoneThings() {
    QueryBuilder<Thing> query() =>
        box.store.box<Thing>().query(Thing_.done.equals(true));
    return SubjectQueryBuilder<Thing>(
      query: query,
    ).behaviorSubject;
  }
}
