import 'package:flutter/material.dart';
import 'package:focus/app/content/ui/content_header.dart';
import 'package:focus/app/thing/ui/thing_base_card.dart';
import 'package:focus/app/common_infrastructure/ui/global_scaffold.dart';

class MockedContentTravelScreen extends StatelessWidget {
  const MockedContentTravelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GlobalScaffold(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ContentHeader(
            ContentHeaderParams(
              title: 'Viagem Paraty',
              subtitle: 'viagens',
              rightText: r'Total: R$ 200,00',
            ),
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
              rightText: r'R$ 4,00',
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
