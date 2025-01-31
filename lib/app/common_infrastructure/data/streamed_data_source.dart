import 'package:objectbox/objectbox.dart';
import 'package:rxdart/subjects.dart';

class SubjectQueryBuilder<T> {
  SubjectQueryBuilder({
    required this.query,
    this.forEachMap,
  }) {
    final initialValue = query().build().find();

    behaviorSubject = BehaviorSubject<List<T>>.seeded(
      initialValue.map(forEachMap ?? (e) => e).toList(),
    );
    query()
        .watch()
        .map(
          (event) => event.find().map(forEachMap ?? (e) => e).toList(),
        )
        .listen(
          behaviorSubject.add,
        );
  }
  final QueryBuilder<T> Function() query;
  final T Function(T)? forEachMap;

  late BehaviorSubject<List<T>> behaviorSubject;
}
