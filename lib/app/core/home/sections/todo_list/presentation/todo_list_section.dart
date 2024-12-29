import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:focus/app/core/home/sections/core/home_section.dart';
import 'package:focus/app/core/thing.dart';
import 'package:focus/app/data/repositories/thing_repository.dart';
import 'package:focus/app/data/stream_cubit.dart';
import 'package:focus/app/ui/base_card.dart';

class TodoListSection extends StatefulWidget {
  const TodoListSection({super.key});

  @override
  State<TodoListSection> createState() => _TodoListSectionState();
}

class _TodoListSectionState extends State<TodoListSection> {
  late StreamCubit<List<Thing>> _streamCubit;

  @override
  void initState() {
    super.initState();
    _streamCubit = StreamCubit<List<Thing>>(
      stream: context.read<ThingRepository>().watchTodoThings(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StreamCubit<List<Thing>>, List<Thing>>(
      bloc: _streamCubit,
      builder: (context, state) {
        return HomeSection(
          mustRender: state.isNotEmpty,
          title: '📃 Listinha',
          content: Column(
            children: state
                .map(
                  (thing) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: BaseCard(
                      thing: thing,
                    ),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }
}
