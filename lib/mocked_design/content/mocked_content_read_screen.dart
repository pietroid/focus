import 'package:flutter/material.dart';
import 'package:focus/app/common/ui/base_card.dart';
import 'package:focus/app/common/ui/elements/global_scaffold.dart';

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
