import 'package:cron/cards/presentation/base_card.dart';
import 'package:flutter/material.dart';

class CurrentTasksSection extends StatelessWidget {
  const CurrentTasksSection({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '⏳ Agora',
          style: textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        const BaseCard(
          title: 'Criar a tela de login',
          subtitle: '16h00 - 18h00',
          color: Color.fromARGB(255, 0, 72, 1),
          loadingProgress: 0.5,
        ),
      ],
    );
  }
}
