import 'package:flutter/material.dart';
import 'package:focus/app/common_infrastructure/ui/nested_draggable_list.dart';
import 'package:focus/app/home/sections/timely/data/timely_data.dart';
import 'package:focus/app/home/sections/timely/ui/timely_base_card_mapper.dart';
import 'package:focus/app/thing/data/thing.dart';
import 'package:focus/app/thing/ui/thing_base_card.dart';
import 'package:provider/provider.dart';

class Timely extends StatelessWidget {
  const Timely({super.key});

  @override
  Widget build(BuildContext context) {
    return NestedDraggableList<Thing, Thing>(
      data: context.read<TimelyData>(),
      keyForList: (thing) => ValueKey(thing.id),
      itemsForList: (list) => list.children,
      listHeader: (list) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(
          list.content,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
      keyForItem: (item) => ValueKey(item.id),
      itemBuilder: (item) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: BaseCard(
          item.toBaseCardParams(context),
        ),
      ),
      onItemReorder:
          (Thing oldList, Thing oldItem, Thing newList, int newItemIndex) {
        context.read<TimelyData>().editThing(
              thing: oldItem,
              newParent: newList,
              newIndex: newItemIndex,
            );
      },
    );
  }
}
