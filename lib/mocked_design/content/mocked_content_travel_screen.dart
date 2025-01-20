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
          Text(
            'Viagem Paraty',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(
            height: 4,
          ),
          Text(
            'Viagens',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(
            height: 20,
          ),
          Text(
            'Sexta-feira',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(
            height: 4,
          ),
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
            ),
          ),
          const SizedBox(
            height: 3,
          ),
          CardShape(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Passeio barco'),
                      Text(
                        '16:00 - 18:00',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Text(
                      //   '16:00 - 18:00',
                      //   style: Theme.of(context).textTheme.bodySmall,
                      // ),
                      Text(
                        r'R$ 240,00',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
