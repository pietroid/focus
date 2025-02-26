import 'package:bloc/bloc.dart';
import 'package:things/things.dart';
import 'package:timely_repository/timely_repository.dart';

class TimelyCubit extends Cubit<List<Thing>> {
  TimelyCubit({
    required this.timelyRepository,
  }) : super(timelyRepository.stream.value) {
    timelyRepository.stream.listen(emit);
  }

  final TimelyRepository timelyRepository;
}
