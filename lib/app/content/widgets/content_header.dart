import 'package:app_ui/app_ui.dart';

import 'package:flutter/material.dart';
import 'package:things/things.dart';

class ContentHeader extends StatelessWidget {
  const ContentHeader({required this.thing, super.key});

  final Thing thing;

  @override
  Widget build(BuildContext context) {
    return ContentHeaderWidget(
      title: thing.content,
      subtitle: 'Total: ${thing.value?.formatAsMoney()}',
    );
  }
}

class ContentHeaderWidget extends StatelessWidget {
  const ContentHeaderWidget({
    required this.title,
    this.subtitle,
    this.rightText,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? rightText;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        if (rightText != null || subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                if (subtitle != null) Text(subtitle!),
                Expanded(
                  child: Container(),
                ),
                if (rightText != null) Text(rightText!),
              ],
            ),
          ),
        const SizedBox(
          height: 20,
        ),
      ],
    );
  }
}
