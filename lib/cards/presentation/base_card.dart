import 'package:flutter/material.dart';

class BaseCard extends StatelessWidget {
  const BaseCard({
    required this.title,
    required this.color,
    this.subtitle,
    this.isDismissable = true,
    this.loadingProgress,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Color color;
  final bool isDismissable;
  final double? loadingProgress;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
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
    );
  }
}
