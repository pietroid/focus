import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:focus/app/core/content/data/content_data.dart';
import 'package:focus/app/core/content/ui/content_header.dart';
import 'package:focus/app/core/elements/nested_draggable_list/nested_draggable_list.dart';
import 'package:focus/app/core/home/core/sections/timely/timely_data.dart';
import 'package:focus/app/core/home/core/sections/timely/timely_thing_extension.dart';
import 'package:focus/app/core/thing.dart';
import 'package:focus/app/data/object_box.dart';
import 'package:focus/app/ui/base_card.dart';
import 'package:focus/app/ui/elements/global_scaffold.dart';
import 'package:provider/provider.dart';

class ContentScreen extends StatelessWidget {
  const ContentScreen({
    required this.thingId,
    super.key,
  });
  final int thingId;

  @override
  Widget build(BuildContext context) {
    return GlobalScaffold(
      child: NestedDraggableList<Thing, Thing>(
        data: ContentData(
          thingId: thingId,
          box: context.read<ObjectBox>(),
        ),
        keyForList: (thing) => ValueKey(thing.id),
        itemsForList: (list) => list.children,
        listHeader: (list) => ContentHeader(
          //TODO: add mapper to this
          ContentHeaderParams(
            title: list.content,
            subtitle: list.value?.formatAsMoney().format(),
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
      ),
    );
  }
}

extension TotalFormatter on String {
  String format() {
    return 'Total: $this';
  }
}
