import 'package:cron/core/domain/note.dart';
import 'package:cron/objectbox.g.dart';
import 'package:cron/shared/object_box.dart';
import 'package:cron/shared/streamed_data_source.dart';
import 'package:rxdart/subjects.dart';

class NoteRepository {
  NoteRepository({
    required this.box,
  });
  final ObjectBox box;

  void addOrEditNote({
    required Note note,
  }) {
    box.store.box<Note>().put(note);
  }

  void setAsDone({
    required Note note,
  }) {
    note.done = true;
    box.store.box<Note>().put(note);
  }

  void setAsUndone({
    required Note note,
  }) {
    note.done = false;
    box.store.box<Note>().put(note);
  }

  BehaviorSubject<List<Note>> watchTodoNotes() {
    QueryBuilder<Note> query() =>
        box.store.box<Note>().query(Note_.done.equals(false));
    return SubjectQueryBuilder<Note>(
      query: query,
    ).behaviorSubject;
  }

  BehaviorSubject<List<Note>> watchDoneNotes() {
    QueryBuilder<Note> query() =>
        box.store.box<Note>().query(Note_.done.equals(true));
    return SubjectQueryBuilder<Note>(
      query: query,
    ).behaviorSubject;
  }
}
