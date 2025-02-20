import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:focus/app/app/ui/app_colors.dart';
import 'package:glowy_borders/glowy_borders.dart';

class BaseCard extends StatefulWidget {
  const BaseCard(
    this.params, {
    super.key,
  });
  final BaseCardParams params;

  @override
  State<BaseCard> createState() => _BaseCardState();
}

class _BaseCardState extends State<BaseCard> {
  bool willDelete = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Dismissible(
      key: Key('bla${widget.params.isDone}'),
      onUpdate: (details) async {
        if (widget.params.isDismissable == false &&
            details.direction == DismissDirection.startToEnd &&
            details.reached &&
            !details.previousReached) {
          willDelete = false;
          await Future.delayed(const Duration(milliseconds: 500));
          if (widget.params.isDone) {
            widget.params.onUndone?.call();
          } else {
            widget.params.onDone?.call();
          }
        }

        if (details.direction == DismissDirection.endToStart &&
            details.reached &&
            !details.previousReached) {
          willDelete = true;
        }
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.startToEnd) {
          if (widget.params.isDone) {
            widget.params.onUndone?.call();
          } else {
            widget.params.onDone?.call();
          }
        } else {
          widget.params.onDelete?.call();
        }
      },
      background: Row(
        children: [
          Icon(
            widget.params.isDone ? Icons.undo : Icons.check,
          ),
        ],
      ),
      confirmDismiss: (direction) =>
          Future.value(widget.params.isDismissable == true || willDelete),
      secondaryBackground: const Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Icon(
            Icons.delete,
          ),
        ],
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: widget.params.onTap,
        onDoubleTap: widget.params.onDoubleTap,
        child: ConditionalWrapper(
          isInProgress: widget.params.isInProgress == true,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        widget.params.title,
                        style: textTheme.bodyMedium?.copyWith(
                          decoration: widget.params.isDone
                              ? TextDecoration.lineThrough
                              : null,
                          color: widget.params.isInProgress == true
                              ? const Color.fromARGB(255, 255, 255, 255)
                              : Colors.white.withOpacity(
                                  widget.params.isDone ? 0.5 : 1,
                                ),
                        ),
                      ),
                      if (widget.params.subtitle != null) ...[
                        Text(
                          widget.params.subtitle!,
                          style: textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                if (widget.params.rightText != null)
                  Text(
                    widget.params.rightText!,
                    style: textTheme.bodySmall,
                  ),
                const SizedBox(width: 10),
                if (widget.params.isDraggable == true)
                  const Icon(
                    size: 15,
                    Icons.menu,
                    color: AppColors.primaryColor,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ConditionalWrapper extends StatelessWidget {
  const ConditionalWrapper({
    required this.isInProgress,
    required this.child,
    super.key,
  });
  final bool isInProgress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return isInProgress
        ? AnimatedGradientBorder(
            borderSize: 0.4,
            glowSize: 2,
            gradientColors: const [
              Color(0xFFEEFFBB),
              Color(0xFF00B481),
              Color(0xFF1B318F),
              Color(0xFF9E2B3D),
              Color(0xFFFF9A6B),
            ],
            animationTime: 4,
            borderRadius: const BorderRadius.all(Radius.circular(10)),
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: ShapeDecoration(
                color: AppColors.defaultCardColor,
                shape: SmoothRectangleBorder(
                  borderRadius: SmoothBorderRadius(
                    cornerRadius: 10,
                    cornerSmoothing: 1,
                  ),
                ),
              ),
              child: child,
            ),
          )
        : Container(
            clipBehavior: Clip.antiAlias,
            decoration: ShapeDecoration(
              color: AppColors.defaultCardColor,
              shape: SmoothRectangleBorder(
                borderRadius: SmoothBorderRadius(
                  cornerRadius: 10,
                  cornerSmoothing: 1,
                ),
              ),
            ),
            child: child,
          );
  }
}

class RightIconButton extends StatelessWidget {
  const RightIconButton({super.key, this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onTap,
      child: const Icon(
        Icons.arrow_right,
        color: AppColors.primaryColor,
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

class BaseCardParams {
  BaseCardParams({
    required this.title,
    required this.id,
    this.rightText,
    this.subtitle,
    this.color,
    this.isInProgress,
    this.onTap,
    this.onDoubleTap,
    this.onDelete,
    this.onDone,
    this.onUndone,
    this.isDone = false,
    this.isDismissable = false,
    this.isOutlined,
    this.isDraggable,
  });

  final String title;
  final String? subtitle;
  final String? rightText;
  final Color? color;
  final bool? isInProgress;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onDone;
  final VoidCallback? onUndone;
  final VoidCallback? onDelete;
  final bool isDone;
  final bool? isDismissable;
  final bool? isOutlined;
  final bool? isDraggable;
  final int id;
}
