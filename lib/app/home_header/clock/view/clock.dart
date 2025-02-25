import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:focus/app/home_header/clock/bloc/clock_cubit.dart';
import 'package:timer/timer.dart';

class Clock extends StatelessWidget {
  const Clock({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return BlocBuilder<ClockCubit, ClockState>(
      bloc: ClockCubit(timerRepository: context.read<TimerRepository>()),
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              state.formattedTime(),
              style: textTheme.displayMedium,
              textAlign: TextAlign.start,
            ),
            Text(
              state.formattedDayOfTheWeek(),
            ),
          ],
        );
      },
    );
  }
}
