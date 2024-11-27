import 'package:cron/core/data/repositories/note_repository.dart';
import 'package:cron/core/domain/note.dart';

class NoteUseCases {
  NoteUseCases({required this.noteRepository});

  final NoteRepository noteRepository;

  void addOrEditNote({
    required Note note,
  }) {
    noteRepository.addOrEditNote(
      note: note,
    );
  }
}
