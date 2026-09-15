import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:focus/home/view/widgets/home_empty_state.dart';
import 'package:go_router/go_router.dart';
import 'package:subject/subject.dart';

/// {@template home_page}
/// Home page that decides between the empty state and the subjects list.
/// {@endtemplate}
class HomePage extends StatelessWidget {
  /// {@macro home_page}
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SubjectBloc, SubjectState>(
      builder: (context, state) {
        if (state.isLoading || state.status == SubjectStatus.initial) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (state.subjects.isEmpty) {
          return const HomeEmptyState();
        }

        return Scaffold(
          body: ListView.builder(
            itemCount: state.subjects.length,
            itemBuilder: (context, index) {
              final subject = state.subjects[index];
              return ListTile(
                title: Text(subject.name),
                onTap: () => context.go('/subject/${subject.id}'),
              );
            },
          ),
        );
      },
    );
  }
}
