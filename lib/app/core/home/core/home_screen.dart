import 'package:flutter/material.dart';
import 'package:focus/app/core/home/sections/done_tasks/presentation/done_tasks_section.dart';
import 'package:focus/app/core/home/sections/empty_state/presentation/empty_state_section.dart';
import 'package:focus/app/core/home/sections/todo_list/presentation/todo_list_section.dart';
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
      child: ListView(
        children: const [
          EmptyStateSection(),
          // CurrentTasksSection(),
          // NextTasksSection(),
          TodoListSection(),
          DoneTasksSection(),
        ],
      ),
    );
  }
}
