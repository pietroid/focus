import 'package:bloc/bloc.dart';
import 'package:focus/app/content/data/content_data.dart';
import 'package:focus/app/home/sections/body/for_you/data/for_you_repository.dart';
import 'package:focus/app/thing/data/thing.dart';

class ContentCubit extends Cubit<List<Thing>> {
  ContentCubit({
    required this.contentRepository,
  }) : super(contentRepository.stream.value) {
    contentRepository.stream.listen(emit);
  }

  final ContentRepository contentRepository;
}
