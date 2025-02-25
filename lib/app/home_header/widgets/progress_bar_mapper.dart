import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';

// Mapping the DateTime to the UI progressBar
class ProgressBarMapper {
  double progressPercentage(DateTime currentTime) {
    final totalDuration = finalTime.difference(initialTime);
    final currentDuration = currentTime.difference(initialTime);

    return currentDuration.inSeconds / totalDuration.inSeconds;
  }

  DateTime get initialTime =>
      DateTime.now().copyWith(hour: 07, minute: 00, second: 0);

  DateTime get finalTime =>
      DateTime.now().copyWith(hour: 22, minute: 00, second: 0);

  String get formattedInitialTime {
    final formatter = DateFormat('☀️HH:mm');
    final formatted = formatter.format(initialTime);
    return formatted;
  }

  String get formattedFinalTime {
    final formatter = DateFormat('HH:mm 😴');
    final formatted = formatter.format(finalTime);
    return formatted;
  }

  LinearGradient gradient = const LinearGradient(
    colors: [
      //morning 07:00 -> 0
      Color.fromARGB(255, 255, 255, 227),
      //mid-day 12:00 -> 5/15
      Color.fromARGB(255, 255, 153, 19),
      //evening 17:00 -> 10/15
      Color.fromARGB(255, 187, 166, 103),
      //sunset 19:00 -> 12/15
      Color.fromARGB(255, 66, 74, 83),
      //night 22:00 -> 1
      Color.fromARGB(255, 11, 33, 60),
    ],
    stops: [0, 5 / 15, 10 / 15, 12 / 15, 1],
  );
}
