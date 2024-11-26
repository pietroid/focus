import 'package:cron/cards/presentation/base_card.dart';
import 'package:flutter/material.dart';

class TodoListSection extends StatelessWidget {
  const TodoListSection({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '📃 Listinha',
          style: textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        const BaseCard(
          title: 'Ver imóveis',
          color: Color.fromARGB(255, 72, 65, 0),
        ),
        const SizedBox(height: 4),
        const BaseCard(
          title: 'Organizar cronograma mudança',
          color: Color.fromARGB(255, 18, 72, 0),
        ),
        const SizedBox(height: 4),
        const BaseCard(
          title: 'Escrever ideias',
          color: Color.fromARGB(255, 0, 72, 62),
        ),
      ],
    );
  }
}
