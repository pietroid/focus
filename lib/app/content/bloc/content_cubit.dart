import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:content_repository/content_repository.dart';
import 'package:things/things.dart';

class ContentCubit extends Cubit<List<Thing>> {
  ContentCubit({
    required this.contentRepository,
  }) : super(contentRepository.stream.value) {
    subscription = contentRepository.stream.listen(emit);
  }
  StreamSubscription<List<Thing>>? subscription;

  final ContentRepository contentRepository;

  @override
  Future<void> close() {
    subscription?.cancel();
    return super.close();
  }
}
