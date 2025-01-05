import 'package:focus/app/core/thing.dart';
import 'package:focus/app/data/object_box.dart';

class DataInitializer {
  DataInitializer({
    required this.box,
  });

  final ObjectBox box;
  void initialize() {
    if (box.store.box<Thing>().isEmpty()) {
      final nowSection = Thing(
        content: '⏰ Agora',
        createdAt: DateTime.now(),
        category: timelyCategory,
      );
      final tomorrowSection = Thing(
        content: '🌞 Amanhã',
        createdAt: DateTime.now(),
        category: timelyCategory,
      );
      final laterSection = Thing(
        content: '📅 Depois',
        createdAt: DateTime.now(),
        category: timelyCategory,
      );

      box.store.box<Thing>().put(nowSection);
      box.store.box<Thing>().put(tomorrowSection);
      box.store.box<Thing>().put(laterSection);
    }
  }
}

const timelyCategory = 'TIMELY';
