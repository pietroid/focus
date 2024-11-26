import 'package:cron/home/current_tasks/presentation/current_tasks_section.dart';
import 'package:cron/home/next_tasks/presentation/next_tasks_section.dart';
import 'package:cron/home/todo_list/presentation/todo_list_section.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ListView(
            children: const [
              CurrentTasksSection(),
              SizedBox(height: 32),
              NextTasksSection(),
              SizedBox(height: 32),
              TodoListSection(),
            ],
          ),
        ),
      ),
    );
  }
}
