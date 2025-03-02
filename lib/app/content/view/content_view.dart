import 'package:app_elements/app_elements.dart';
import 'package:content_repository/content_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:focus/app/content/bloc/content_cubit.dart';
import 'package:focus/app/content/widgets/content_header.dart';
import 'package:focus/app/focus/view/global_scaffold.dart';
import 'package:focus/app/home/body/mappers/base_card_mapper.dart';
import 'package:things/things.dart';

class ContentView extends StatelessWidget {
  const ContentView({
    required this.thingId,
    super.key,
  });
  final int thingId;

  @override
  Widget build(BuildContext context) {
    return GlobalScaffold(
      child: BlocBuilder<ContentCubit, List<Thing>>(
        bloc: ContentCubit(
          thingId: thingId,
          contentRepository: context.read<ContentRepository>(),
        ),
        builder: (context, state) => NestedDraggableList<Thing, Thing>(
          data: state,
          keyForList: (thing) => ValueKey(thing.id),
          itemsForList: (list) => list.children,
          listHeader: (list) => ContentHeader(
            thing: list,
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
            Thing oldList,
            Thing oldItem,
            Thing newList,
            int newItemIndex,
          ) {
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
