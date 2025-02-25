import 'package:flutter/material.dart';

class Clock extends StatelessWidget {
  const Clock({
    required this.time,
    required this.dayOfTheWeek,
    super.key,
  });
  final String time;
  final String dayOfTheWeek;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          time,
          style: textTheme.displayMedium,
          textAlign: TextAlign.start,
        ),
        Text(dayOfTheWeek),
      ],
    );
  }
}
