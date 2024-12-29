import 'package:focus/objectbox.g.dart';
import 'package:rxdart/subjects.dart';

class SubjectQueryBuilder<T> {
  SubjectQueryBuilder({
    required this.query,
  }) {
    final initialValue = query().build().find();

    behaviorSubject = BehaviorSubject<List<T>>.seeded(initialValue);
    query().watch().map((event) => event.find()).listen(
          behaviorSubject.add,
        );
  }
  final QueryBuilder<T> Function() query;

  late BehaviorSubject<List<T>> behaviorSubject;
}
