import 'package:focus/app/core/thing.dart';
import 'package:focus/app/data/domain_data.dart';
import 'package:focus/app/data/streamed_data_source.dart';
import 'package:focus/objectbox.g.dart';
import 'package:rxdart/subjects.dart';

class GenericThingData extends DomainData<Thing> {
  GenericThingData({
    required this.thingId,
    required super.box,
  });
  final int thingId;

  @override
  BehaviorSubject<List<Thing>> get stream {
    return SubjectQueryBuilder<Thing>(
      query: () => box.store.box<Thing>().query(
            Thing_.id.equals(thingId),
          ),
    ).behaviorSubject;
  }
}
