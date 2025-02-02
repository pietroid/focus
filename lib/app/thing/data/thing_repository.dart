import 'package:focus/app/thing/data/initializer.dart';
import 'package:focus/app/thing/data/thing.dart';
import 'package:focus/app/common_infrastructure/data/object_box.dart';
import 'package:focus/app/common_infrastructure/data/streamed_data_source.dart';
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

  void changeThingPriority({
    required Thing thing,
    required Thing newParent,
    required int newIndex,
  }) {
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
