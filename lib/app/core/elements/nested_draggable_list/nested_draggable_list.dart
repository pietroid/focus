import 'package:drag_and_drop_lists/drag_and_drop_lists.dart';
import 'package:flutter/widgets.dart';
import 'package:focus/app/core/home/core/sections/timely/timely_data.dart';

class NestedDraggableList<L, I> extends StatelessWidget {
  const NestedDraggableList({
    required this.delegate,
    required this.keyForList,
    required this.itemsForList,
    required this.listHeader,
    required this.keyForItem,
    required this.itemBuilder,
    required this.onItemReorder,
    super.key,
  });
  final DataObserverDelegate<L> delegate;
  final Key Function(L) keyForList;
  final List<I> Function(L) itemsForList;
  final Widget Function(L) listHeader;

  final Key Function(I) keyForItem;
  final Widget Function(I) itemBuilder;
  final void Function(L, I, L, int) onItemReorder;

  @override
  Widget build(BuildContext context) {
    return DataObserver<L>(
      delegate: delegate,
      builder: (context, state) => DragAndDropLists(
        contentsWhenEmpty: Container(),
        children: state.map((list) {
          return DragAndDropList(
            key: keyForList(list),
            contentsWhenEmpty: Container(),
            children: itemsForList(list)
                .map(
                  (child) => DragAndDropItem(
                    key: keyForItem(child),
                    child: itemBuilder(child),
                  ),
                )
                .toList(),
            header: listHeader(list),
          );
        }).toList(),
        onItemReorder: (
          int oldItemIndex,
          int oldListIndex,
          int newItemIndex,
          int newListIndex,
        ) =>
            onItemReorder(
          state[oldListIndex],
          itemsForList(state[oldListIndex])[oldItemIndex],
          state[newListIndex],
          newItemIndex,
        ),
        onListReorder: (_, __) {},
      ),
    );
  }
}
