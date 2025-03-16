import 'package:local_service/local_service.dart';
import 'package:rxdart/subjects.dart';
import 'package:things/things.dart';

const intervalBetweenThings = Duration(minutes: 5);

class TimelyRepository {
  TimelyRepository({
    required this.box,
  });

  ObjectBox box;

  BehaviorSubject<List<Thing>> get stream {
    QueryBuilder<Thing> query() => box.store.box<Thing>().query(
          Thing_.tags
              .containsElement(todaySectionTag)
              .or(Thing_.tags.containsElement(nowSectionTag)),
        );

    return SubjectQueryBuilder<Thing>(
      query: query,
      forEachMap: (thing) {
        //haven't found a better way to sort the children via query
        thing.children.sort((a, b) => a.rank.compareTo(b.rank));
        thing.children.applyToDb();
        return thing;
      },
    ).behaviorSubject;
  }

  void listenToDurationChanges() {
    List<Thing> latestItems = [];
    stream.listen((nowAndTodayThings) {
      final currentItems = [
        ...nowAndTodayThings.first.children.toList(),
        ...nowAndTodayThings[1].children.toList()
      ];

      bool equalList = true;
      if (currentItems.length == latestItems.length) {
        for (int i = 0; i < currentItems.length; i++) {
          if (!(currentItems[i].duration == latestItems[i].duration &&
              isAlmostEqualOrNull(
                  currentItems[i].startTime, latestItems[i].startTime) &&
              isAlmostEqualOrNull(
                  currentItems[i].endTime, latestItems[i].endTime))) {
            equalList = false;
            break;
          }
        }
      } else {
        equalList = false;
      }

      if (equalList) return;

      DateTime currentInitialTime = DateTime.now();

      for (final item in currentItems) {
        item.startTime = currentInitialTime;
        box.store.box<Thing>().put(item);

        currentInitialTime =
            currentInitialTime.add(item.duration ?? Duration.zero);
        currentInitialTime = currentInitialTime.add(intervalBetweenThings);
      }

      latestItems = currentItems.toList();

      // for (final nowAndTodayThing in nowAndTodayThings) {
      //   nowAndTodayThing.startTime = currentInitialTime;
      //   box.store.box<Thing>().put(nowAndTodayThing);

      //   currentInitialTime =
      //       currentInitialTime.add(nowAndTodayThing.duration ?? Duration.zero);
      //   currentInitialTime = currentInitialTime.add(intervalBetweenThings);
      // }
    });
  }
}

bool isAlmostEqualOrNull(DateTime? a, DateTime? b) {
  if (a == null && b == null) return true;
  if (a == null || b == null) return false;
  return a.difference(b).inSeconds < 10;
}
