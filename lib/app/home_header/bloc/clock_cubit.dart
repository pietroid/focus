import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:intl/intl.dart';
import 'package:meta/meta.dart';
import 'package:app_ui/src/string_formatter.dart';
import 'package:timer/timer.dart';

part 'clock_state.dart';

class ClockCubit extends Cubit<ClockState> {
  ClockCubit({
    required TimerRepository timerRepository,
  }) : super(ClockState(currentTime: timerRepository.currentTime)) {
    timerSubscription = timerRepository.currentTimeStream.listen(
      (time) => emit(
        ClockState(currentTime: time),
      ),
    );
  }
  StreamSubscription<DateTime>? timerSubscription;

  @override
  Future<void> close() {
    timerSubscription?.cancel();
    return super.close();
  }
}
