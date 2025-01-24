import 'package:focus/app/core/initializer.dart';
import 'package:focus/app/core/thing.dart';
import 'package:focus/app/data/object_box.dart';
import 'package:focus/app/data/streamed_data_source.dart';
import 'package:focus/objectbox.g.dart';
import 'package:rxdart/subjects.dart';

class ThingRepository {
  ThingRepository({
    required this.box,
  });
  final ObjectBox box;

  void addThing({
    required Thing thing,
    int? parentId,
  }) {
    if (parentId != null) {
      final parent = box.store.box<Thing>().get(parentId);
      if (parent == null) {
        return;
      }
      thing.parents.add(parent);
      parent.children.add(thing);
      parent.children.applyToDb();
    } else {
      final todaySection = box.store
          .box<Thing>()
          .query(Thing_.tags.containsElement(todaySectionTag))
          .build()
          .findFirst();
      if (todaySection != null) {
        thing.rank = todaySection.children.length;
        box.store.box<Thing>().put(thing);
        todaySection.children.add(thing);
        todaySection.children.applyToDb();
      }
    }
    box.store.box<Thing>().put(thing);
  }

  void editThing({
    required Thing thing,
  }) {
    box.store.box<Thing>().put(thing);
  }

  void setAsDone({
    required Thing thing,
  }) {
    thing.done = true;

    if (thing.parents.first.tags.contains(timelyTag)) {
      thing.parents.first.children.removeWhere((child) => child.id == thing.id);
      thing.parents.first.children.applyToDb();
      final doneThing = box.store
          .box<Thing>()
          .query(Thing_.content.equals('✅ Feito'))
          .build()
          .findFirst();

      if (doneThing != null) {
        thing.rank = doneThing.children.length;
        doneThing.children.add(thing);
        doneThing.children.applyToDb();
      }
    }

    box.store.box<Thing>().put(thing);
  }

  void setAsUndone({
    required Thing thing,
  }) {
    thing.done = false;

    if (thing.parents.first.tags.contains(timelyTag)) {
      thing.parents.first.children.removeWhere((child) => child.id == thing.id);
      thing.parents.first.children.applyToDb();
      final doneThing = box.store
          .box<Thing>()
          .query(Thing_.tags.containsElement(nowSectionTag))
          .build()
          .findFirst();

      if (doneThing != null) {
        thing.rank = doneThing.children.length;
        doneThing.children.add(thing);
        doneThing.children.applyToDb();
      }
    }
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
