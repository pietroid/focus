part of 'home_body_cubit.dart';

@immutable
class HomeBodyState {
  const HomeBodyState({
    required this.timelySections,
    required this.forYouSection,
  });

  final List<HomeBodySection> timelySections;
  final HomeBodySection forYouSection;

  List<HomeBodySection> get allSections => [...timelySections, forYouSection];

  HomeBodyState copyWith({
    List<HomeBodySection>? timelySections,
    HomeBodySection? forYouSection,
  }) =>
      HomeBodyState(
        timelySections: timelySections ?? this.timelySections,
        forYouSection: forYouSection ?? this.forYouSection,
      );
}

class HomeBodySection {
  HomeBodySection({
    required this.mainThing,
    required this.children,
    required this.type,
    this.selectedTab,
    this.tabs,
  });

  final Thing mainThing;
  final Thing? selectedTab;
  final List<Thing> children;
  final List<Thing>? tabs;
  final HomeBodySectionType type;

  HomeBodySection copyWith({
    Thing? mainThing,
    Thing? selectedTab,
    List<Thing>? children,
    List<Thing>? tabs,
    HomeBodySectionType? type,
  }) =>
      HomeBodySection(
        mainThing: mainThing ?? this.mainThing,
        selectedTab: selectedTab ?? this.selectedTab,
        children: children ?? this.children,
        tabs: tabs ?? this.tabs,
        type: type ?? this.type,
      );
}

enum HomeBodySectionType {
  regular,
  carousel,
}
