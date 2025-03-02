import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';

class FieldButton extends StatelessWidget {
  const FieldButton({
    required this.icon,
    required this.label,
    required this.onChanged,
    this.disabled = false,
    super.key,
  });
  final IconData icon;
  final String label;
  final void Function(String value) onChanged;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        color:
            disabled ? AppColors.disabledCardColor : AppColors.defaultCardColor,
      ),
      child: Padding(
        padding: const EdgeInsets.only(
          left: 8,
          right: 8,
          top: 8,
          bottom: 8,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: disabled
                  ? AppColors.disabledIconColor
                  : AppColors.primaryColor,
            ),
          ],
        ),
      ),
    );
  }
}
