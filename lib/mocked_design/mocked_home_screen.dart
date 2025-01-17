import 'package:flutter/material.dart';
import 'package:focus/app/ui/base_card.dart';
import 'package:focus/app/ui/elements/global_scaffold.dart';

class MockedHomeScreen extends StatelessWidget {
  const MockedHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GlobalScaffold(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '13:37',
                textAlign: TextAlign.start,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const Text(
                '🌙 Quarta-feira, 15 de janeiro',
                textAlign: TextAlign.start,
              ),
            ],
          ),
          const SizedBox(
            height: 30,
          ),
          Text(
            '⏱️ Agora',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(
            height: 10,
          ),
          BaseCard(
            BaseCardParams(
              title: 'Resolver plano de saúde',
              onTap: () {},
              openOptions: () {},
              isInProgress: true,
            ),
          ),
          const SizedBox(
            height: 25,
          ),
          Text(
            '⏳ Ainda hoje',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(
            height: 10,
          ),
          BaseCard(
            BaseCardParams(
              title: 'Terminar focus',
              subtitle: '23:00',
              onTap: () {},
              openOptions: () {},
            ),
          ),
          const SizedBox(
            height: 3,
          ),
          BaseCard(
            BaseCardParams(
              title: 'Preparar para dormir',
              onTap: () {},
              openOptions: () {},
            ),
          ),
          const SizedBox(
            height: 30,
          ),
          const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
          ),
          const SizedBox(
            height: 30,
          ),
        ],
      ),
    );
  }
}

class ThinSeparator extends StatelessWidget {
  const ThinSeparator({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: const Color.fromARGB(255, 103, 103, 103),
    );
  }
}

// class Wrapper extends StatelessWidget {
//   const Wrapper({required this.children, required this.color, super.key});
//   final List<Widget> children;
//   final Color color;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: color,
//         borderRadius: const BorderRadius.all(Radius.circular(25)),
//         border: Border.all(
//           color: const Color.fromARGB(255, 255, 255, 255),
//           width: 0.2,
//         ),
//       ),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         crossAxisAlignment: CrossAxisAlignment.stretch,
//         children: children,
//       ),
//     );
//   }
// }
