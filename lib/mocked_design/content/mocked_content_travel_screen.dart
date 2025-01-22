import 'package:flutter/material.dart';
import 'package:focus/app/ui/base_card.dart';
import 'package:focus/app/ui/elements/global_scaffold.dart';
import 'package:focus/mocked_design/mocked_home_screen.dart';

class MockedContentTravelScreen extends StatelessWidget {
  const MockedContentTravelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GlobalScaffold(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ThingContentHeader(),
          BaseCard(
            BaseCardParams(
              title: 'Viagem ônibus',
              subtitle: '09:00 - 14:50',
            ),
          ),
          const SizedBox(
            height: 3,
          ),
          BaseCard(
            BaseCardParams(
              title: 'Check-in hotel',
              subtitle: '15:00',
              rightText: 'R\$ 4,00',
            ),
          ),
          const SizedBox(
            height: 3,
          ),
        ],
      ),
    );
  }
}

class ThingContentHeader extends StatelessWidget {
  const ThingContentHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Viagem Paraty',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        SizedBox(
          height: 10,
        ),
        Row(
          children: [
            Text('Viagens'),
            Expanded(
              child: Container(),
            ),
            Text('Total: R\$ 2450,00')
          ],
        ),
        const SizedBox(
          height: 20,
        ),
      ],
    );
  }
}
