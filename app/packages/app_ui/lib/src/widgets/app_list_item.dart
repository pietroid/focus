import 'package:app_ui/app_ui.dart';

/// {@template app_list_item}
/// One row of a list: an icon, a line to read, and an optional second line.
///
/// The icon is what makes a list scannable, so it is given a colour that means
/// something and a fixed column of its own. Titles then start at the same x
/// whether or not the row above had a subtitle, and the eye runs straight down
/// them.
/// {@endtemplate}
class AppListItem extends StatelessWidget {
  /// {@macro app_list_item}
  const AppListItem({
    required this.title,
    this.subtitle,
    this.iconData,
    this.color = AppColors.ink2,
    this.onTap,
    super.key,
  });

  /// The line that is read first.
  final String title;

  /// An optional supporting line.
  final String? subtitle;

  /// The leading icon.
  final AppIconData? iconData;

  /// What the icon's colour says about the row.
  final Color color;

  /// Makes the whole row tappable when given.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final icon = iconData;
    final supporting = subtitle;

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Padding(
            // Nudged down so the glyph sits on the title's optical centre
            // rather than on its ascender line.
            padding: const EdgeInsets.only(top: 2),
            child: AppIcon(iconData: icon, size: AppSpacing.s5, color: color),
          ),
          const SizedBox(width: AppSpacing.s3),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.bodyStrong),
              if (supporting != null && supporting.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.s1),
                Text(
                  supporting,
                  style: AppTypography.label.copyWith(color: AppColors.ink2),
                ),
              ],
            ],
          ),
        ),
        if (onTap != null)
          const Padding(
            padding: EdgeInsets.only(left: AppSpacing.s2, top: 2),
            child: AppIcon(
              iconData: AppIcons.chevronRight,
              size: AppSpacing.s4,
              color: AppColors.ink3,
            ),
          ),
      ],
    );

    if (onTap == null) return row;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
        child: row,
      ),
    );
  }
}
