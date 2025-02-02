import 'package:bloc/bloc.dart';
import 'package:focus/app/home/sections/body/for_you/data/for_you_repository.dart';
import 'package:focus/app/thing/data/thing.dart';

class ForYouCubit extends Cubit<List<Thing>> {
  ForYouCubit({
    required this.forYouRepository,
  }) : super(forYouRepository.stream.value) {
    forYouRepository.stream.listen(emit);
  }

  final ForYouRepository forYouRepository;
}
