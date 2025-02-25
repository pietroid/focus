import 'package:focus/app/thing/data/initializer.dart';
import 'package:focus/app/thing/data/thing.dart';
import 'package:focus/objectbox.g.dart';
import 'package:local_service/local_service.dart';
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

  void removeThing({
    required Thing thing,
  }) {
    box.store.box<Thing>().remove(thing.id);
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
    final existingParent = thing.parents.first;
    if (newParent.id != existingParent.id) {
      existingParent.children.removeWhere((child) => child.id == thing.id);
      existingParent.children.applyToDb();

      existingParent.children.sort((a, b) => a.rank.compareTo(b.rank));
      for (var i = 0; i < existingParent.children.length; i++) {
        existingParent.children[i].rank = i;
        box.store.box<Thing>().put(existingParent.children[i]);
      }
      existingParent.children.applyToDb();

      newParent.children.add(thing);
      newParent.children.applyToDb();
    }

    newParent.children.sort((a, b) => a.rank.compareTo(b.rank));
    newParent.children.removeWhere((child) => child.id == thing.id);
    newParent.children.insert(newIndex, thing);
    newParent.children.applyToDb();
    for (var i = 0; i < newParent.children.length; i++) {
      newParent.children[i].rank = i;
      box.store.box<Thing>().put(newParent.children[i]);
    }
    newParent.children.applyToDb();
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
