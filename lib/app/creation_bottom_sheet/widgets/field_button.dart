import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';

class FieldButton extends StatelessWidget {
  const FieldButton({
    required this.icon,
    required this.onTap,
    this.label,
    this.disabled = false,
    super.key,
  });
  final IconData icon;
  final String? label;
  final VoidCallback onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(20)),
          color: AppColors.defaultCardColor,
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
                color: disabled ? AppColors.disabledIconColor : Colors.white,
              ),
              if (label != null) ...[
                const SizedBox(
                  width: 5,
                ),
                Text(
                  label!,
                  style: const TextStyle(
                    fontSize: 12,
                  ),
                ),
                const SizedBox(
                  width: 3,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
