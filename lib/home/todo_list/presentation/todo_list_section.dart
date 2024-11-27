import 'package:cron/cards/presentation/base_card.dart';
import 'package:cron/core/data/repositories/note_repository.dart';
import 'package:cron/core/domain/note.dart';
import 'package:cron/shared/stream_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TodoListSection extends StatefulWidget {
  const TodoListSection({super.key});

  @override
  State<TodoListSection> createState() => _TodoListSectionState();
}

class _TodoListSectionState extends State<TodoListSection> {
  late StreamCubit<List<Note>> _streamCubit;

  @override
  initState() {
    super.initState();
    _streamCubit = StreamCubit<List<Note>>(
      stream: context.read<NoteRepository>().watchNotes(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return BlocBuilder<StreamCubit<List<Note>>, List<Note>>(
      bloc: _streamCubit,
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📃 Listinha',
              style: textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            ...state.map(
              (note) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: BaseCard(
                  title: note.content,
                  color: const Color(0xFF00ACBB),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
