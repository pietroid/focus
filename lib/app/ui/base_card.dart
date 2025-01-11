import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:focus/app/core/home/core/sections/timely/timely_thing_extension.dart';
import 'package:focus/app/core/thing.dart';
import 'package:focus/app/data/repositories/thing_repository.dart';
import 'package:focus/app/ui/app_colors.dart';
import 'package:focus/app/ui/creation_bottom_sheet.dart';
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
      isInProgress: thing.inProgress,
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
    this.isInProgress,
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
  final bool? isInProgress;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity! > 0) {
          onChanged?.call();
        }
        if (details.primaryVelocity! < 0) {
          onChanged?.call();
        }
      },
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: ShapeDecoration(
          color: color ?? AppColors.defaultCardColor,
          shape: SmoothRectangleBorder(
            borderRadius: SmoothBorderRadius(
              cornerRadius: 10,
              cornerSmoothing: 1,
            ),
          ),
          //borderRadius: BorderRadius.circular(14),
        ),
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              child: Row(
                children: [
                  if (isInProgress == true) ...[
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 1,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          title,
                          style: textTheme.bodyMedium?.copyWith(
                            decoration: hasBeenDismissed
                                ? TextDecoration.lineThrough
                                : null,
                            color: Colors.white
                                .withOpacity(hasBeenDismissed ? 0.5 : 1),
                          ),
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
        width: 18,
        height: 18,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          border: Border.fromBorderSide(
            BorderSide(
              width: 0.5,
              color: AppColors.primaryColor,
            ),
          ),
        ),
        child: value
            ? const Center(
                child: Icon(
                  Icons.check,
                  size: 12,
                  color: AppColors.primaryColor,
                ),
              )
            : null,
      ),
    );
  }
}
