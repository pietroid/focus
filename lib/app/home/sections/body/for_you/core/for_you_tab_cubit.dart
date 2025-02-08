import 'package:bloc/bloc.dart';
import 'package:focus/app/thing/data/thing.dart';

class ForYouTabCubit extends Cubit<Thing> {
  ForYouTabCubit({
    required Thing initialTab,
  }) : super(initialTab);

  void changeTab(Thing newTab) {
    emit(newTab);
  }
}
