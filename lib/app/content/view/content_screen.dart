import 'package:app_elements/app_elements.dart';
import 'package:content_repository/content_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:focus/app/content/bloc/content_cubit.dart';
import 'package:focus/app/content/widgets/content_header.dart';
import 'package:focus/app/focus/view/global_scaffold.dart';
import 'package:focus/app/home/body/widgets/timely_base_card_mapper.dart';
import 'package:local_service/local_service.dart';
import 'package:things/things.dart';

class ContentScreen extends StatelessWidget {
  const ContentScreen({
    required this.thingId,
    super.key,
  });
  final int thingId;

  @override
  Widget build(BuildContext context) {
    return GlobalScaffold(
      child: BlocBuilder<ContentCubit, List<Thing>>(
        bloc: ContentCubit(
          contentRepository: ContentRepository(
            thingId: thingId,
            box: context.read<ObjectBox>(),
          ),
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

extension TotalFormatter on String {
  String format() {
    return 'Total: $this';
  }
}
