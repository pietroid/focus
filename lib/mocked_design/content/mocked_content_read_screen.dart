import 'package:flutter/material.dart';
import 'package:focus/app/thing/ui/thing_base_card.dart';
import 'package:focus/app/common_infrastructure/ui/global_scaffold.dart';

class MockedContentReadScreen extends StatelessWidget {
  const MockedContentReadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GlobalScaffold(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Autobiografia de um Iogue',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(
            height: 4,
          ),
          Text(
            '📕 Anotações de Leituras',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(
            height: 20,
          ),
          BaseCard(
            BaseCardParams(
              id: 0,
              title:
                  'Fui buscar a vassoura; o Mestre, eu sabia, estava me ensinando o segredo da vida equilibrada.\n\nA alma deve alargar-se sobre os abismos cosmogônicos, enquanto o corpo executa seus deveres diários.',
              subtitle: 'Página 135',
            ),
          ),
          const SizedBox(
            height: 3,
          ),
          BaseCard(
            BaseCardParams(
              id: 1,
              title:
                  'Deus é sempre renovada alegria. Ele é inesgotável; à medida que você prosseguir em suas meditações, durante anos, Ele o fascinará com infinita capacidade inventiva.',
              subtitle: 'Página 139',
            ),
          ),
        ],
      ),
    );
  }
}
