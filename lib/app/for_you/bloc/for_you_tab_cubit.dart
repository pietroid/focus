import 'package:bloc/bloc.dart';
import 'package:things/things.dart';

class ForYouTabCubit extends Cubit<Thing> {
  ForYouTabCubit({
    required Thing initialTab,
  }) : super(initialTab);

  void changeTab(Thing newTab) {
    emit(newTab);
  }
}
