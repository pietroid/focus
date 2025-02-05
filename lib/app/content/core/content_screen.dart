import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:focus/app/common_infrastructure/data/data_observer.dart';
import 'package:focus/app/content/data/content_data.dart';
import 'package:focus/app/content/ui/content_header.dart';
import 'package:focus/app/common_infrastructure/ui/nested_draggable_list.dart';
import 'package:focus/app/home/sections/body/timely/data/timely_repository.dart';
import 'package:focus/app/home/sections/body/timely/ui/timely_base_card_mapper.dart';
import 'package:focus/app/thing/data/thing.dart';
import 'package:focus/app/common_infrastructure/data/object_box.dart';
import 'package:focus/app/thing/data/thing_repository.dart';
import 'package:focus/app/thing/ui/thing_base_card.dart';
import 'package:focus/app/common_infrastructure/ui/global_scaffold.dart';
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
      child: DataObserver<Thing>(
        data: ContentData(
          thingId: thingId,
          box: context.read<ObjectBox>(),
        ),
        builder: (context, state) => NestedDraggableList<Thing, Thing>(
          data: state,
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
            context.read<ThingRepository>().changeThingPriority(
                  thing: oldItem,
                  newParent: newList,
                  newIndex: newItemIndex,
                );
          },
        ),
      ),
    );
  }
}

extension TotalFormatter on String {
  String format() {
    return 'Total: $this';
  }
}
