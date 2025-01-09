import 'package:focus/app/core/initializer.dart';
import 'package:focus/app/core/thing.dart';
import 'package:focus/app/data/object_box.dart';
import 'package:focus/app/data/streamed_data_source.dart';
import 'package:focus/objectbox.g.dart';
import 'package:rxdart/subjects.dart';

class TodaySectionDelegate implements DataObserverDelegate<Thing> {
  TodaySectionDelegate({
    required this.box,
  });

  final ObjectBox box;

  @override
  BehaviorSubject<List<Thing>> get dataStream {
    QueryBuilder<Thing> query() =>
        box.store.box<Thing>().query(Thing_.category.equals(timelyCategory));
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

  void editThing({
    required Thing thing,
    required Thing newParent,
    required int newIndex,
  }) {
    // final existingParent = box.store
    //     .box<Thing>()
    //     .query(Thing_.id.equals(newParent.id))
    //     .build()
    //     .findFirst();
    // if (existingParent != null) {
    final oldRank = thing.rank;
    thing.rank = newIndex;
    box.store.box<Thing>().put(thing);
    newParent.children.applyToDb();

    final existingParent = thing.parents.first;
    if (newParent.id != existingParent.id) {
      existingParent.children.removeWhere((child) => child.id == thing.id);
      existingParent.children.applyToDb();

      newParent.children.add(thing);
      newParent.children.applyToDb();
    }

    for (final child in existingParent.children) {
      if (child.id != thing.id && child.rank > oldRank) {
        child.rank--;
        box.store.box<Thing>().put(child);
      }
    }
    existingParent.children.applyToDb();

    final newOrExistingParent =
        newParent.id == existingParent.id ? existingParent : newParent;
    // re-rank
    for (final child in newOrExistingParent.children) {
      if (child.id != thing.id && child.rank >= newIndex) {
        child.rank++;
        box.store.box<Thing>().put(child);
      }
    }
    newOrExistingParent.children.applyToDb();
  }
}

abstract class DataObserverDelegate<T> {
  BehaviorSubject<List<T>> get dataStream;
}
