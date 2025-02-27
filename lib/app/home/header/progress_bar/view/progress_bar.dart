import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:focus/app/home/header/progress_bar/bloc/progress_bar_cubit.dart';
import 'package:timer/timer.dart';

class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProgressBarCubit, ProgressBarState>(
      bloc: ProgressBarCubit(timerRepository: context.read<TimerRepository>()),
      builder: (context, state) {
        return ProgressBarContent(
          gradient: state.gradient,
          progressPercentage: state.progressPercentage(),
          initialValue: state.formattedInitialTime,
          finalValue: state.formattedFinalTime,
        );
      },
    );
  }
}

class ProgressBarContent extends StatelessWidget {
  const ProgressBarContent({
    required this.progressPercentage,
    required this.gradient,
    super.key,
    this.initialValue,
    this.finalValue,
    this.midValue,
  });
  final double progressPercentage;
  final Gradient gradient;
  final String? initialValue;
  final String? finalValue;
  final String? midValue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 3,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: const BorderRadius.all(Radius.circular(4)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              Flexible(
                flex: (progressPercentage * 100).toInt(),
                fit: FlexFit.tight,
                child: Container(),
              ),
              Flexible(
                fit: FlexFit.tight,
                flex: ((1 - progressPercentage) * 100).toInt(),
                child: Container(
                  color: AppColors.defaultCardColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        if (initialValue != null || finalValue != null || midValue != null)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                initialValue ?? '',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                midValue ?? '',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                finalValue ?? '',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
      ],
    );
  }
}
