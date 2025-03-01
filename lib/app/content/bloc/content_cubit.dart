import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:content_repository/content_repository.dart';
import 'package:things/things.dart';

class ContentCubit extends Cubit<List<Thing>> {
  ContentCubit({
    required this.thingId,
    required this.contentRepository,
  }) : super(contentRepository.stream(thingId: thingId).value) {
    subscription = contentRepository.stream(thingId: thingId).listen(emit);
  }
  int thingId;
  StreamSubscription<List<Thing>>? subscription;

  final ContentRepository contentRepository;

  @override
  Future<void> close() {
    subscription?.cancel();
    return super.close();
  }
}
