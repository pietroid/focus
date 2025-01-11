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
        content: '⏱️ Agora',
        createdAt: DateTime.now(),
        tags: [
          timelyTag,
          versionTag,
        ],
      );
      final todaySection = Thing(
        content: '⏳ Ainda hoje',
        createdAt: DateTime.now(),
        tags: [
          timelyTag,
          todaySectionTag,
          versionTag,
        ],
      );
      final tomorrowSection = Thing(
        content: '🌞 Amanhã',
        createdAt: DateTime.now(),
        tags: [
          timelyTag,
          versionTag,
        ],
      );
      final laterSection = Thing(
        content: '📅 Depois',
        createdAt: DateTime.now(),
        tags: [
          timelyTag,
          versionTag,
        ],
      );
      final doneSection = Thing(
        content: '✅ Feito',
        createdAt: DateTime.now(),
        tags: [
          timelyTag,
          versionTag,
        ],
      );

      box.store.box<Thing>().put(nowSection);
      box.store.box<Thing>().put(todaySection);
      box.store.box<Thing>().put(tomorrowSection);
      box.store.box<Thing>().put(laterSection);
      box.store.box<Thing>().put(doneSection);
    }
  }
}

const timelyTag = 'TIMELY';
const todaySectionTag = 'TODAY_SECTION';
const versionTag = 'VERSION_v0.2';
