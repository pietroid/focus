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

  void addNote({
    required Note note,
  }) {
    box.store.box<Note>().put(note);
  }

  BehaviorSubject<List<Note>> watchNotes() {
    QueryBuilder<Note> query() => box.store.box<Note>().query();
    return SubjectQueryBuilder<Note>(
      query: query,
    ).behaviorSubject;
  }
}
