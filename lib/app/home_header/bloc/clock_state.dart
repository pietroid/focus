part of 'clock_cubit.dart';

@immutable
class ClockState {
  const ClockState({required this.currentTime});

  final DateTime currentTime;
}

extension TimeMapper on ClockState {
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
