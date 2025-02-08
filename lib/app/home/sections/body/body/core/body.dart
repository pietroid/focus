import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:focus/app/common_infrastructure/ui/nested_draggable_list.dart';
import 'package:focus/app/home/sections/body/body/core/home_body_builder.dart';
import 'package:focus/app/home/sections/body/body/ui/list_header.dart';
import 'package:focus/app/home/sections/body/timely/ui/timely_base_card_mapper.dart';
import 'package:focus/app/thing/data/thing.dart';
import 'package:focus/app/thing/data/thing_repository.dart';
import 'package:focus/app/thing/ui/thing_base_card.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class HomeBody extends StatelessWidget {
  const HomeBody({super.key});

  @override
  Widget build(BuildContext context) {
    return HomeBodyBuilder(
      builder: (context, state) => NestedDraggableList<HomeBodySection, Thing>(
        data: state,
        keyForList: (section) => ValueKey(section.mainThing.id),
        itemsForList: (list) => list.children,
        listHeader: (list) => ListHeader(
          section: list,
          onTap: () {
            context.push('/thing/${list.mainThing.id}');
          },
        ),
        keyForItem: (item) => ValueKey(item.id),
        itemBuilder: (item) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: BaseCard(
            item.toBaseCardParams(context),
          ),
        ),
        onItemReorder: (
          HomeBodySection oldSection,
          Thing oldItem,
          HomeBodySection newSection,
          int newItemIndex,
        ) {
          context.read<ThingRepository>().changeThingPriority(
                thing: oldItem,
                newParent: newSection.selectedTab ?? newSection.mainThing,
                newIndex: newItemIndex,
              );
        },
      ),
    );
  }
}
