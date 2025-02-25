import 'package:focus/app/thing/data/thing.dart';
import 'package:local_service/local_service.dart';

class DataInitializer {
  DataInitializer({
    required this.box,
  });

  final ObjectBox box;
  void initialize() {
    // Create from scratch
    if (box.store.box<Thing>().isEmpty()) {
      final nowSection = Thing(
        content: '⏱️ Agora',
        createdAt: DateTime.now(),
        tags: [
          timelyTag,
          nowSectionTag,
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
          tomorrowSectionTag,
          versionTag,
        ],
      );
      final laterSection = Thing(
        content: '📅 Depois',
        createdAt: DateTime.now(),
        tags: [
          timelyTag,
          laterSectionTag,
          versionTag,
        ],
      );
      final doneSection = Thing(
        content: '✅ Feito',
        createdAt: DateTime.now(),
        tags: [
          timelyTag,
          doneSectionTag,
          versionTag,
        ],
      );
      final forYouSection = Thing(
        content: '❤️ Você',
        createdAt: DateTime.now(),
        tags: [
          forYouTag,
          versionTag,
        ],
      );

      box.store.box<Thing>().put(nowSection);
      box.store.box<Thing>().put(todaySection);
      box.store.box<Thing>().put(tomorrowSection);
      box.store.box<Thing>().put(laterSection);
      box.store.box<Thing>().put(doneSection);

      forYouSection.children.add(tomorrowSection);
      forYouSection.children.add(laterSection);
      forYouSection.children.add(doneSection);

      box.store.box<Thing>().put(forYouSection);
    }
    // final doneThing = box.store
    //     .box<Thing>()
    //     .query(Thing_.content.equals('✅ Feito'))
    //     .build()
    //     .findFirst()!;
    // doneThing.tags.add(doneSectionTag);
    // box.store.box<Thing>().put(doneThing);

    // final laterSection = box.store
    //     .box<Thing>()
    //     .query(Thing_.content.equals('📅 Depois'))
    //     .build()
    //     .findFirst()!;
    // laterSection.tags.add(laterSectionTag);
    // box.store.box<Thing>().put(laterSection);

    // final tomorrowSection = box.store
    //     .box<Thing>()
    //     .query(Thing_.content.equals('🌞 Amanhã'))
    //     .build()
    //     .findFirst()!;
    // tomorrowSection.tags.add(tomorrowSectionTag);
    // box.store.box<Thing>().put(tomorrowSection);

    // final forYouSection = box.store
    //     .box<Thing>()
    //     .query(Thing_.tags.containsElement(forYouTag))
    //     .build()
    //     .findFirst()!;
    // print(forYouSection.content);

    // final tomorrowSection = box.store
    //     .box<Thing>()
    //     .query(Thing_.tags.containsElement(tomorrowSectionTag))
    //     .build()
    //     .findFirst()!;

    // print(tomorrowSection.content);

    // final laterSection = box.store
    //     .box<Thing>()
    //     .query(Thing_.tags.containsElement(laterSectionTag))
    //     .build()
    //     .findFirst()!;

    // final doneSection = box.store
    //     .box<Thing>()
    //     .query(Thing_.tags.containsElement(doneSectionTag))
    //     .build()
    //     .findFirst()!;

    // forYouSection.children.add(tomorrowSection);
    // forYouSection.children.add(laterSection);
    // forYouSection.children.add(doneSection);

    // box.store.box<Thing>().put(forYouSection);
  }
}

//TIMELY
const timelyTag = 'TIMELY';

// SECTIONS
const todaySectionTag = 'TODAY_SECTION';
const nowSectionTag = 'NOW_SECTION';
const tomorrowSectionTag = 'TOMORROW_SECTION';
const laterSectionTag = 'LATER_SECTION';
const doneSectionTag = 'DONE_SECTION';

// FOR YOU SECTION
const forYouTag = 'FOR_YOU';

//VERSION
const versionTag = 'VERSION_v0.2';
