import 'package:app_ui/app_ui.dart';
import 'package:chat/src/bloc/threads_bloc.dart';
import 'package:chat/src/widgets/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// {@template threads_section}
/// The home screen's middle band: the user's threads.
///
/// Grouping is the next thing to land here, by theme and by day. For now every
/// thread is one flat list, most recently touched first.
/// {@endtemplate}
class ThreadsSection extends StatelessWidget {
  /// {@macro threads_section}
  const ThreadsSection({required this.onThreadTap, super.key});

  /// Called with a thread's slug when its row is tapped.
  final ValueChanged<String> onThreadTap;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThreadsBloc, ThreadsState>(
      builder: (context, state) {
        if (state.isInitialLoad) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.s6),
            child: Column(
              children: [
                AppSkeleton(
                  height: AppSpacing.s16,
                  radius: AppSpacing.chipRadius,
                ),
                SizedBox(height: AppSpacing.s3),
                AppSkeleton(
                  height: AppSpacing.s16,
                  radius: AppSpacing.chipRadius,
                ),
              ],
            ),
          );
        }

        if (state.threads.isEmpty) return const SizedBox.shrink();

        return ListView.separated(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s6,
            vertical: AppSpacing.s2,
          ),
          itemCount: state.threads.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s3),
          itemBuilder: (context, index) {
            final thread = state.threads[index];

            return ThreadTile(
              thread: thread,
              onTap: () => onThreadTap(thread.slug),
            );
          },
        );
      },
    );
  }
}
