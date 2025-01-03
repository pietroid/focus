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
          children: state
              .map(
                (data) => DragAndDropList(
                  contentsWhenEmpty: Container(),
                  children: data.children
                      .map(
                        (child) => DragAndDropItem(
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
                  header: Text(
                    data.content,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
              )
              .toList(),
          onItemReorder: (_, __, ___, ____) {},
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
