import 'package:focus/app/core/initializer.dart';
import 'package:focus/app/core/thing.dart';

extension TimelyThingExtension on Thing {
  bool get inProgress => parents.first.tags.contains(nowSectionTag);
}
