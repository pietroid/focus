import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:subject/subject.dart';

/// {@template home_empty_state}
/// A widget that displays an empty state for the home page and allows the
/// user to create their first subject.
/// {@endtemplate}
class HomeEmptyState extends StatefulWidget {
  /// {@macro home_empty_state}
  const HomeEmptyState({super.key});

  @override
  State<HomeEmptyState> createState() => _HomeEmptyStateState();
}

class _HomeEmptyStateState extends State<HomeEmptyState> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _createSubject() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;

    context.read<SubjectBloc>().add(SubjectCreated(name));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Focus',
              style: Theme.of(
                context,
              ).textTheme.headlineLarge?.copyWith(letterSpacing: -1),
            ),
            const SizedBox(height: AppSpacing.xlg),
            SizedBox(
              width: 400,
              child: Column(
                children: [
                  Text(
                    'Qual primeiro assunto que você deseja estudar?',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  BlocBuilder<SubjectBloc, SubjectState>(
                    buildWhen: (previous, current) =>
                        previous.isCreating != current.isCreating,
                    builder: (context, state) {
                      return Column(
                        children: [
                          AppTextField(
                            controller: _controller,
                            enabled: !state.isCreating,
                            onSubmitted: (_) => _createSubject(),
                          ),
                          if (state.isCreating) ...[
                            const SizedBox(height: AppSpacing.md),
                            const CircularProgressIndicator(),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
