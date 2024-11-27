import 'package:cron/core/data/repositories/note_repository.dart';
import 'package:cron/core/domain/note.dart';
import 'package:cron/home/sections/core/home_section.dart';
import 'package:cron/shared/stream_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class EmptyStateSection extends StatefulWidget {
  const EmptyStateSection({super.key});

  @override
  State<EmptyStateSection> createState() => _EmptyStateSectionState();
}

class _EmptyStateSectionState extends State<EmptyStateSection> {
  late StreamCubit<List<Note>> _hasNotesCubit;

  @override
  void initState() {
    //TODO change this query on the future because of performance (limit it or return just bool)
    _hasNotesCubit = StreamCubit<List<Note>>(
      stream: context.read<NoteRepository>().watchTodoNotes(),
    );
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StreamCubit<List<Note>>, List<Note>>(
      bloc: _hasNotesCubit,
      builder: (context, state) => HomeSection(
        mustRender: _hasNotesCubit.state.isEmpty,
        title: '📝 Nada por aqui',
        content: const Text('Clique no + para criar alguma nota ou tarefa!'),
      ),
    );
  }
}
