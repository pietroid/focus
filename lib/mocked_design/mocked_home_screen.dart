import 'package:flutter/material.dart';
import 'package:focus/app/ui/base_card.dart';
import 'package:focus/app/ui/elements/global_scaffold.dart';

class MockedHomeScreen extends StatelessWidget {
  const MockedHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GlobalScaffold(
      child: Column(
        children: [
          BaseCard(
            BaseCardParams(
              title: 'Mocked design',
              subtitle: 'Próxima tarefa',
              onTap: () {},
            ),
          ),
          const SizedBox(
            height: 3,
          ),
          BaseCard(
            BaseCardParams(
              title: 'Vamos usar o poder do subtítulo',
              subtitle: 'Teste',
              onTap: () {},
            ),
          ),
        ],
      ),
    );
  }
}
