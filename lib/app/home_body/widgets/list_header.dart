import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:focus/app/home_body/body/widgets/home_body_builder.dart';
import 'package:focus/app/home_body/body/widgets/choice_selector.dart';
import 'package:focus/app/for_you/bloc/for_you_tab_cubit.dart';
import 'package:focus/app/thing/data/thing.dart';

class ListHeader extends StatelessWidget {
  const ListHeader({
    required this.section,
    required this.onTap,
    super.key,
  });
  final HomeBodySection section;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: section.type == HomeBodySectionType.regular
            ? Text(
                section.mainThing.content,
                style: Theme.of(context).textTheme.headlineMedium,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.mainThing.content,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  SizedBox(
                    height: 40,
                    child: CarouselSelector(
                      children: section.children,
                      tabs: section.tabs ?? [],
                      selectedIndex: section.tabs?.indexWhere(
                            (tab) => tab.id == section.selectedTab?.id,
                          ) ??
                          0,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class CarouselSelector extends StatelessWidget {
  const CarouselSelector({
    required this.children,
    required this.tabs,
    required this.selectedIndex,
    super.key,
  });
  final List<Thing> children;
  final List<Thing> tabs;
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      separatorBuilder: (context, index) => const SizedBox(width: 4),
      shrinkWrap: true,
      itemBuilder: (context, index) => ChoiceSelector(
        isSelected: selectedIndex == index,
        label: tabs[index].content,
        onTap: () {
          context.read<ForYouTabCubit>().changeTab(tabs[index]);
        },
      ),
      scrollDirection: Axis.horizontal,
      itemCount: tabs.length,
    );
  }
}
