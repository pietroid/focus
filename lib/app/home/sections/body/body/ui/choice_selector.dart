import 'package:flutter/material.dart';
import 'package:focus/app/app/ui/app_colors.dart';

class ChoiceSelector extends StatelessWidget {
  const ChoiceSelector({
    required this.label,
    this.onTap,
    super.key,
  });

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.defaultCardColor,
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        child: Center(child: Text(label)),
      ),
    );
  }
}
