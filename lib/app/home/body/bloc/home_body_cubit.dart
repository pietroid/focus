import 'package:bloc/bloc.dart';
import 'package:for_you_repository/for_you_repository.dart';
import 'package:meta/meta.dart';
import 'package:things/things.dart';
import 'package:timely_repository/timely_repository.dart';

part 'home_body_state.dart';

class HomeBodyCubit extends Cubit<HomeBodyState> {
  HomeBodyCubit({
    required this.timelyRepository,
    required this.forYouRepository,
  }) : super(
          HomeBodyState(
            timelySections: timelyRepository.stream.value
                .map(
                  (thing) => HomeBodySectionMapper.mapTimelySection(
                    thing: thing,
                  ),
                )
                .toList(),
            forYouSection: HomeBodySectionMapper.mapForYouSection(
              thing: forYouRepository.stream.value.first,
              selectedTab: forYouRepository.stream.value.first.children.first,
            ),
          ),
        ) {
    timelyRepository.stream.listen((things) {
      emit(
        state.copyWith(
          timelySections: timelyRepository.stream.value
              .map(
                (thing) => HomeBodySectionMapper.mapTimelySection(
                  thing: thing,
                ),
              )
              .toList(),
        ),
      );
    });

    forYouRepository.stream.listen((things) {
      emit(
        state.copyWith(
          forYouSection: HomeBodySectionMapper.mapForYouSection(
            thing: things.first,
            selectedTab: state.forYouSection.selectedTab,
          ),
        ),
      );
    });
  }

  void selectTab({required Thing tab}) {
    emit(
      state.copyWith(
        forYouSection: HomeBodySectionMapper.mapForYouSection(
          thing: state.forYouSection.mainThing,
          selectedTab: tab,
        ),
      ),
    );
  }

  final TimelyRepository timelyRepository;
  final ForYouRepository forYouRepository;
}

class HomeBodySectionMapper {
  static HomeBodySection mapTimelySection({required Thing thing}) {
    return HomeBodySection(
      mainThing: thing,
      children: thing.children,
      type: HomeBodySectionType.regular,
    );
  }

  static HomeBodySection mapForYouSection({
    required Thing thing,
    required Thing? selectedTab,
  }) {
    return HomeBodySection(
      selectedTab: selectedTab,
      mainThing: thing,
      tabs: thing.children,
      children:
          thing.children.firstWhere((e) => e.id == selectedTab?.id).children,
      type: HomeBodySectionType.carousel,
    );
  }
}
