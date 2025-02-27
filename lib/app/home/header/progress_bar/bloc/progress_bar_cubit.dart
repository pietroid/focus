import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:meta/meta.dart';
import 'package:timer/timer.dart';

part 'progress_bar_state.dart';

class ProgressBarCubit extends Cubit<ProgressBarState> {
  ProgressBarCubit({
    required TimerRepository timerRepository,
  }) : super(ProgressBarState(currentTime: timerRepository.currentTime)) {
    timerSubscription = timerRepository.currentTimeStream.listen(
      (time) => emit(
        ProgressBarState(currentTime: time),
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
