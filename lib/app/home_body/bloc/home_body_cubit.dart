import 'package:bloc/bloc.dart';
import 'package:meta/meta.dart';
import 'package:things/things.dart';

part 'home_body_state.dart';

class HomeBodyCubit extends Cubit<HomeBodyState> {
  HomeBodyCubit() : super(const HomeBodyState(sections: []));
}
