import 'package:flutter/material.dart';

class ContentHeaderParams {
  const ContentHeaderParams({
    required this.title,
    this.subtitle,
    this.rightText,
  });

  final String title;
  final String? subtitle;
  final String? rightText;
}

class ContentHeader extends StatelessWidget {
  const ContentHeader(
    this.params, {
    super.key,
  });

  final ContentHeaderParams params;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          params.title,
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        if (params.rightText != null || params.subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                if (params.subtitle != null) Text(params.subtitle!),
                Expanded(
                  child: Container(),
                ),
                if (params.rightText != null) Text(params.rightText!),
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
