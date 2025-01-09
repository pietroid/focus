import 'package:focus/app/data/object_box.dart';
import 'package:rxdart/subjects.dart';

abstract class DomainData<T> {
  DomainData({
    required this.box,
  });

  final ObjectBox box;
  BehaviorSubject<List<T>> get stream;
}
