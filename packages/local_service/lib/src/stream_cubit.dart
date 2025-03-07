import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:rxdart/subjects.dart';

// This cubit shouldn't be here actually (this package is just for service)
class StreamCubit<T> extends Cubit<T> {
  StreamCubit({
    required this.stream,
  }) : super(
          stream.value,
        ) {
    _subscription = stream.listen(
      emit,
    );
  }
  StreamSubscription<T>? _subscription;

  @override
  final BehaviorSubject<T> stream;

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
