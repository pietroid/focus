import 'package:drag_and_drop_lists/drag_and_drop_lists.dart';
import 'package:flutter/material.dart';
import 'package:focus/app/core/home/core/sections/today.dart';
import 'package:focus/app/core/thing.dart';
import 'package:focus/app/ui/base_card.dart';
import 'package:focus/app/ui/creation_bottom_sheet.dart';
import 'package:focus/app/ui/elements/global_scaffold.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final creationBottomSheet = context.read<CreationBottomSheet>();
    return GlobalScaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF00ACBB),
        onPressed: () {
          creationBottomSheet.show(context);
        },
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.black),
      ),
      child: DataObserver(
        delegate: context.read<TodaySectionDelegate>(),
        builder: (context, state) => DragAndDropLists(
          contentsWhenEmpty: Container(),
          children: state.map((data) {
            return DragAndDropList(
              key: ValueKey(data.id),
              contentsWhenEmpty: Container(),
              children: data.children
                  .map(
                    (child) => DragAndDropItem(
                      key: ValueKey(child.id),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: BaseCard(
                          thing: Thing(
                            content: child.content,
                            createdAt: child.createdAt,
                            done: child.done,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
              header: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  data.content,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
            );
          }).toList(),
          onItemReorder: (
            int oldItemIndex,
            int oldListIndex,
            int newItemIndex,
            int newListIndex,
          ) {
            final oldList = state[oldListIndex];
            final oldItem = oldList.children[oldItemIndex];
            context.read<TodaySectionDelegate>().editThing(
                  thing: oldItem,
                  newParent: state[newListIndex],
                  newIndex: newItemIndex,
                );
          },
          onListReorder: (_, __) {},
        ),
      ),
    );
  }
}

// class DragAndDropDataList<T> extends DragAndDropList {
//   DragAndDropDataList({
//     required this.delegate,
//     required this.itemBuilder,
//   }) : super(
//           children: [],
//         );
//   final DataObserverDelegate<T> delegate;
//   final DragAndDropItem Function(BuildContext context, List<T> data)
//       itemBuilder;

//   @override
//   Widget generateWidget(DragAndDropBuilderParameters params) {
//     return Container(
//       child: super.generateWidget(params),
//     );
//   }
// }
