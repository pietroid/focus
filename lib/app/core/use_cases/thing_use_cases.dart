import 'package:cron/app/core/thing.dart';
import 'package:cron/app/data/repositories/thing_repository.dart';

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
