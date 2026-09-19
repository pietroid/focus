import 'package:app_ui/app_ui.dart';
import 'package:chat/src/models/models.dart';
import 'package:intl/intl.dart';

/// {@template thread_tile}
/// One thread on the home screen's list.
///
/// Title, last line, and when it was last touched. The preview is the thread's
/// most recent message, so the list says where each conversation got to rather
/// than only what it was called.
/// {@endtemplate}
class ThreadTile extends StatelessWidget {
  /// {@macro thread_tile}
  const ThreadTile({required this.thread, required this.onTap, super.key});

  /// The thread to draw.
  final ThreadSummary thread;

  /// Called when the row is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.fill,
      borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s4,
            vertical: AppSpacing.s3,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (thread.solved) ...[
                          const AppIcon(
                            iconData: AppIcons.check,
                            size: AppSpacing.s4,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: AppSpacing.s2),
                        ],
                        Expanded(
                          child: Text(
                            thread.title,
                            style: AppTypography.body.copyWith(
                              // A closed thread keeps its place in the list but
                              // stops competing for attention with the open
                              // ones above it.
                              color: thread.solved
                                  ? AppColors.ink2
                                  : AppColors.ink,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (thread.preview.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.s1),
                      Text(
                        thread.preview,
                        style: AppTypography.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              Text(
                _stamp(thread.updatedAt),
                style: AppTypography.caption.copyWith(color: AppColors.ink3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The time for a thread touched today, the date for an older one.
  static String _stamp(DateTime at) {
    final now = DateTime.now();
    final isToday =
        at.year == now.year && at.month == now.month && at.day == now.day;

    return isToday ? DateFormat.Hm().format(at) : DateFormat.MMMd().format(at);
  }
}
