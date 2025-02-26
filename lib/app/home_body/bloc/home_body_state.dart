part of 'home_body_cubit.dart';

@immutable
class HomeBodyState {
  const HomeBodyState({
    required this.sections,
  });

  final List<HomeBodySection> sections;
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
}

enum HomeBodySectionType {
  regular,
  carousel,
}
