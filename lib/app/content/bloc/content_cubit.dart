import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:focus/app/content/data/content_data.dart';
import 'package:focus/app/for_you/data/for_you_repository.dart';
import 'package:focus/app/thing/data/thing.dart';

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
