import 'package:bloc/bloc.dart';
import 'package:focus/app/home_timely_section/data/timely_repository.dart';
import 'package:focus/app/thing/data/thing.dart';

class TimelyCubit extends Cubit<List<Thing>> {
  TimelyCubit({
    required this.timelyRepository,
  }) : super(timelyRepository.stream.value) {
    timelyRepository.stream.listen(emit);
  }

  final TimelyRepository timelyRepository;
}
