import 'package:cron/core/domain/note.dart';
import 'package:cron/objectbox.g.dart';
import 'package:cron/shared/object_box.dart';

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

  QueryBuilder<Note> defaultNotesQuery() {
    return box.store.box<Note>().query();
  }
}
