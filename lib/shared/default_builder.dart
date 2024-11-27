import 'package:objectbox/objectbox.dart';

class DefaultBuilder<T> {
  DefaultBuilder({
    required this.query,
  });

  Query<T> query;
}
