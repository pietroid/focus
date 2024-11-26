import 'package:cron/cards/presentation/base_card.dart';
import 'package:flutter/material.dart';

class NextTasksSection extends StatelessWidget {
  const NextTasksSection({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '⏰ Próximos',
          style: textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        const BaseCard(
          title: 'Definir gerenciamento de estados',
          subtitle: '09h00 - 09h30',
          color: Color.fromARGB(255, 0, 58, 72),
        ),
        const SizedBox(height: 4),
        const BaseCard(
          title: 'Criar estrutura de notas',
          subtitle: '09h30 - 10h00',
          color: Color.fromARGB(255, 18, 72, 0),
        ),
      ],
    );
  }
}
