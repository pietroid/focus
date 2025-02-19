import 'package:flutter/material.dart';
import 'package:focus/app/app/ui/app_colors.dart';

class ChoiceSelector extends StatelessWidget {
  const ChoiceSelector({
    required this.label,
    required this.isSelected,
    this.onTap,
    super.key,
  });

  final String label;
  final VoidCallback? onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.defaultCardColor,
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          border: isSelected
              ? const Border.fromBorderSide(
                  BorderSide(
                    color: AppColors.primaryColor,
                  ),
                )
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        child: Center(child: Text(label)),
      ),
    );
  }
}
