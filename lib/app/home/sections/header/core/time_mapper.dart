import 'package:focus/app/common_infrastructure/ui/string_formatter.dart';
import 'package:focus/app/home/sections/header/data/timer/timer_cubit.dart';
import 'package:intl/intl.dart';

// Mapping the TimerState to the UI
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
