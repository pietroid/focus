import 'package:flutter/material.dart';

class HomeSection extends StatelessWidget {
  const HomeSection({
    required this.mustRender,
    required this.title,
    required this.content,
    super.key,
    this.action,
  });
  final bool mustRender;
  final String title;
  final Widget? action;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    return mustRender
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                content,
              ],
            ),
          )
        : const SizedBox();
  }
}
