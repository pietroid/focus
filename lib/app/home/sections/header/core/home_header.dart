import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:focus/app/home/sections/header/core/progress_bar_mapper.dart';
import 'package:focus/app/home/sections/header/core/time_mapper.dart';
import 'package:focus/app/home/sections/header/data/timer/timer_cubit.dart';
import 'package:focus/app/home/sections/header/ui/clock.dart';
import 'package:focus/app/common_infrastructure/ui/string_formatter.dart';
import 'package:focus/app/home/sections/header/ui/progress_bar.dart';
import 'package:intl/intl.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final progressBarMapper = ProgressBarMapper();
    return BlocBuilder<TimerCubit, TimerState>(
      builder: (context, state) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Clock(
              time: state.formattedTime(),
              dayOfTheWeek: state.formattedDayOfTheWeek(),
            ),
            const SizedBox(height: 15),
            ProgressBar(
              gradient: progressBarMapper.gradient,
              progressPercentage:
                  progressBarMapper.progressPercentage(state.currentTime),
              initialValue: progressBarMapper.formattedInitialTime,
              finalValue: progressBarMapper.formattedFinalTime,
            ),
          ],
        ),
      ),
    );
  }
}
