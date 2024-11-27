import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:objectbox/objectbox.dart';

class QueryCubit<T> extends Cubit<List<T>> {
  QueryCubit({
    required this.query,
  }) : super(
          query().build().find(),
        ) {
    _subscription = query().watch().map((query) => query.find()).listen(
          emit,
        );
  }
  StreamSubscription<List<T>>? _subscription;

  final QueryBuilder<T> Function() query;

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
