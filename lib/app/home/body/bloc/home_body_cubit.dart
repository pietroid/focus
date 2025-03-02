import 'package:bloc/bloc.dart';
import 'package:focus/app/home/body/mappers/home_body_section_mapper.dart';
import 'package:for_you_repository/for_you_repository.dart';
import 'package:meta/meta.dart';
import 'package:things/things.dart';
import 'package:timely_repository/timely_repository.dart';

part 'home_body_state.dart';

class HomeBodyCubit extends Cubit<HomeBodyState> {
  HomeBodyCubit({
    required this.timelyRepository,
    required this.forYouRepository,
    required this.homeBodySectionMapper,
  }) : super(
          HomeBodyState(
            timelySections: timelyRepository.stream.value
                .map(
                  (thing) => homeBodySectionMapper.mapTimelySection(
                    thing: thing,
                  ),
                )
                .toList(),
            forYouSection: homeBodySectionMapper.mapForYouSection(
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
                (thing) => homeBodySectionMapper.mapTimelySection(
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
          forYouSection: homeBodySectionMapper.mapForYouSection(
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
        forYouSection: homeBodySectionMapper.mapForYouSection(
          thing: state.forYouSection.mainThing,
          selectedTab: tab,
        ),
      ),
    );
  }

  final TimelyRepository timelyRepository;
  final ForYouRepository forYouRepository;
  final HomeBodySectionMapper homeBodySectionMapper;
}
