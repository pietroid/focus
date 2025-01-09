import 'package:flutter/material.dart';
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
          //color: color ?? AppColors.defaultCardColor,
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: [
              color ?? AppColors.defaultCardColor,
              color ?? AppColors.defaultCardSecondaryColor,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomRight,
          ),
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
                  if (onChanged != null)
                    CheckBox(
                      onChanged: () => onChanged!(),
                      value: hasBeenDismissed,
                    ),
                  const SizedBox(width: 10),
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
        width: 16,
        height: 16,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              Color.fromARGB(255, 0, 15, 41),
              Color.fromARGB(255, 0, 17, 47),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          // border: Border.fromBorderSide(
          // BorderSide(
          //   width: 0.5,
          //   color: Color.fromARGB(255, 0, 15, 44),
          // ),
          // ),
        ),
        child: value
            ? Center(
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color.fromARGB(255, 29, 64, 130),
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
