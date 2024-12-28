import 'package:cron/core/core/thing.dart';
import 'package:cron/core/data/repositories/thing_repository.dart';
import 'package:cron/home/sections/core/home_section.dart';
import 'package:cron/shared/presentation/base_card.dart';
import 'package:cron/shared/stream_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DoneTasksSection extends StatefulWidget {
  const DoneTasksSection({super.key});

  @override
  State<DoneTasksSection> createState() => _DoneTasksSectionState();
}

class _DoneTasksSectionState extends State<DoneTasksSection> {
  late StreamCubit<List<Thing>> _streamCubit;

  @override
  void initState() {
    super.initState();
    _streamCubit = StreamCubit<List<Thing>>(
      stream: context.read<ThingRepository>().watchDoneThings(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StreamCubit<List<Thing>>, List<Thing>>(
      bloc: _streamCubit,
      builder: (context, state) {
        return HomeSection(
          mustRender: state.isNotEmpty,
          title: '🎉 Concluídas',
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
