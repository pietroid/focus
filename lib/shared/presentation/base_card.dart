import 'package:cron/core/core/thing.dart';
import 'package:cron/core/data/repositories/thing_repository.dart';
import 'package:cron/core/ui/creation_bottom_sheet.dart';
import 'package:cron/shared/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class BaseCard extends StatelessWidget {
  const BaseCard({
    required this.thing,
    super.key,
  });
  final Thing thing;

  @override
  Widget build(BuildContext context) {
    final creationBottomSheet = context.read<CreationBottomSheet>();

    return BaseCardContent(
      title: thing.content,
      onTap: () {
        creationBottomSheet.show(
          context,
          existingThing: thing,
        );
      },
      hasBeenDismissed: thing.done,
      onChanged: () {
        if (thing.done) {
          context.read<ThingRepository>().setAsUndone(thing: thing);
          return;
        }
        context.read<ThingRepository>().setAsDone(thing: thing);
      },
    );
  }
}

class BaseCardContent extends StatelessWidget {
  const BaseCardContent({
    required this.title,
    this.color,
    this.subtitle,
    this.loadingProgress,
    this.onTap,
    this.onChanged,
    this.hasBeenDismissed = false,
    super.key,
  });

  final VoidCallback? onTap;
  final VoidCallback? onChanged;
  final bool hasBeenDismissed;
  final String title;
  final String? subtitle;
  final Color? color;
  final double? loadingProgress;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return GestureDetector(
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
                  if (onChanged != null)
                    CheckBox(
                      onChanged: () => onChanged!(),
                      value: hasBeenDismissed,
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

class CheckBox extends StatelessWidget {
  const CheckBox({
    required this.onChanged,
    required this.value,
    super.key,
  });

  final VoidCallback onChanged;
  final bool value;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onChanged,
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.fromBorderSide(
            BorderSide(
              color: Colors.white.withOpacity(0.3),
            ),
          ),
        ),
        child: value ? const Icon(Icons.check, size: 12) : null,
      ),
    );
  }
}
