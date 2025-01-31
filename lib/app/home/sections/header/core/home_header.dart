import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:focus/app/home/sections/header/data/timer/timer_cubit.dart';
import 'package:focus/app/home/sections/header/ui/clock.dart';
import 'package:focus/app/common/ui/string_formatter.dart';
import 'package:intl/intl.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TimerCubit, TimerState>(
      builder: (context, state) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Clock(
          time: state.formattedTime(),
          dayOfTheWeek: state.formattedDayOfTheWeek(),
        ),
      ),
    );
  }
}

extension TimeMapper on TimerState {
  String formattedTime() {
    final formatter = DateFormat('HH:mm');
    final formatted = formatter.format(currentTime);
    return formatted;
  }

  String formattedDayOfTheWeek() {
    final formatter = DateFormat('MMMMEEEEd');
    final formatted = formatter.format(currentTime);
    return formatted.capitalize();
  }
}
