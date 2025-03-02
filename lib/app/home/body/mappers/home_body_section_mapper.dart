import 'package:focus/app/home/body/bloc/home_body_cubit.dart';
import 'package:things/things.dart';

class HomeBodySectionMapper {
  HomeBodySection mapTimelySection({required Thing thing}) {
    return HomeBodySection(
      mainThing: thing,
      children: thing.children,
      type: HomeBodySectionType.regular,
    );
  }

  HomeBodySection mapForYouSection({
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
