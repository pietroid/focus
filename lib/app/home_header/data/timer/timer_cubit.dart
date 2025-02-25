import 'package:bloc/bloc.dart';
import 'package:meta/meta.dart';

part 'timer_state.dart';

class TimerCubit extends Cubit<TimerState> {
  TimerCubit({
    required DateTime startTime,
  }) : super(TimerState(currentTime: startTime)) {
    Stream.periodic(
      const Duration(seconds: 1),
    ).listen((_) {
      emit(TimerState(currentTime: DateTime.now()));
    });
  }
}
