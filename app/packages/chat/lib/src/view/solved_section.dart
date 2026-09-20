import 'package:app_ui/app_ui.dart';
import 'package:chat/src/bloc/threads_bloc.dart';
import 'package:chat/src/models/models.dart';
import 'package:chat/src/widgets/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// {@template solved_section}
/// Everything that has been solved.
///
/// The same cards as the timeline, with one thing added: the way back. A
/// thread solved by mistake is one tap from the list it came from, because a
/// gesture that removes something from the only screen that shows it has to
/// be as easy to undo as it was to do.
/// {@endtemplate}
class SolvedSection extends StatelessWidget {
  /// {@macro solved_section}
  const SolvedSection({required this.onThreadTap, super.key});

  /// Called with a thread's slug when its card is tapped.
  final ValueChanged<String> onThreadTap;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThreadsBloc, ThreadsState>(
      builder: (context, state) {
        final threads = state.solved;

        if (threads.isEmpty) return const _Empty();

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s6,
            AppSpacing.s2,
            AppSpacing.s6,
            // Room under the last card so the bar never covers it.
            AppSpacing.s16 + AppSpacing.s12,
          ),
          itemCount: threads.length,
          separatorBuilder: (context, index) =>
              const SizedBox(height: AppSpacing.s1),
          itemBuilder: (context, index) => _Row(
            thread: threads[index],
            onTap: () => onThreadTap(threads[index].slug),
            onRecover: () => context.read<ThreadsBloc>().add(
              ThreadSolved(threads[index].slug, solved: false),
            ),
          ),
        );
      },
    );
  }
}

/// One solved thread: the card, and the way back out of here.
class _Row extends StatelessWidget {
  const _Row({
    required this.thread,
    required this.onTap,
    required this.onRecover,
  });

  final ThreadSummary thread;
  final VoidCallback onTap;
  final VoidCallback onRecover;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: ThreadTile(thread: thread),
          ),
        ),
        AppIconButton(
          iconData: AppIcons.undo,
          onPressed: onRecover,
          size: AppSpacing.s5,
          color: AppColors.ink2,
        ),
      ],
    );
  }
}

/// What the screen says before anything has been solved.
class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6),
      child: Text(
        'Nada concluído ainda. Arraste um item para o lado para concluí-lo.',
        style: AppTypography.body.copyWith(color: AppColors.ink3),
      ),
    );
  }
}
