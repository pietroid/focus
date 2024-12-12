import 'package:cron/core/data/repositories/thing_repository.dart';
import 'package:cron/core/domain/thing.dart';

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
