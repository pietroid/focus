import 'package:cron/core/domain/note.dart';
import 'package:cron/core/view/creation_bottom_sheet.dart';
import 'package:cron/shared/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class BaseCard extends StatelessWidget {
  const BaseCard({
    required this.note,
    super.key,
  });
  final Note note;

  @override
  Widget build(BuildContext context) {
    final creationBottomSheet = context.read<CreationBottomSheet>();

    return BaseCardContent(
      title: note.content,
      onTap: () {
        creationBottomSheet.show(
          context,
          existingNote: note,
        );
      },
    );
  }
}

class BaseCardContent extends StatelessWidget {
  const BaseCardContent({
    required this.title,
    this.color,
    this.subtitle,
    this.isDismissable = true,
    this.loadingProgress,
    this.onTap,
    super.key,
  });

  final VoidCallback? onTap;
  final String title;
  final String? subtitle;
  final Color? color;
  final bool isDismissable;
  final double? loadingProgress;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: color ?? AppColors.defaultCardColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          title,
                        ),
                        if (subtitle != null) ...[
                          Text(
                            subtitle!,
                            style: textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (loadingProgress != null)
              LinearProgressIndicator(
                value: loadingProgress,
                backgroundColor: const Color(0x55000000),
                valueColor: const AlwaysStoppedAnimation(Color(0x99FFFFFF)),
              ),
          ],
        ),
      ),
    );
  }
}
