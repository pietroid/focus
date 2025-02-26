import 'package:bloc/bloc.dart';
import 'package:for_you_repository/for_you_repository.dart';
import 'package:things/things.dart';

class ForYouCubit extends Cubit<List<Thing>> {
  ForYouCubit({
    required this.forYouRepository,
  }) : super(forYouRepository.stream.value) {
    forYouRepository.stream.listen(emit);
  }

  final ForYouRepository forYouRepository;
}
