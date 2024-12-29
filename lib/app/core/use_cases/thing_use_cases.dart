import 'package:focus/app/core/thing.dart';
import 'package:focus/app/data/repositories/thing_repository.dart';

class ThingUseCases {
  ThingUseCases({required this.thingRepository});

  final ThingRepository thingRepository;

  void addOrEditThing({
    required Thing thing,
  }) {
    thingRepository.addOrEditThing(
      thing: thing,
    );
  }
}
