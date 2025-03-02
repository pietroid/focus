import 'package:app_elements/app_elements.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:focus/app/home/body/bloc/home_body_cubit.dart';
import 'package:focus/app/home/body/mappers/base_card_mapper.dart';
import 'package:focus/app/home/body/widgets/list_header.dart';
import 'package:go_router/go_router.dart';
import 'package:things/things.dart';

class HomeBody extends StatelessWidget {
  const HomeBody({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeBodyCubit, HomeBodyState>(
      builder: (context, state) => NestedDraggableList<HomeBodySection, Thing>(
        data: state.allSections,
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
            context
                .read<BaseCardMapper>()
                .toBaseCardParams(context: context, thing: item),
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
