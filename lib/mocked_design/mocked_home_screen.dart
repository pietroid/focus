import 'package:app_ui/app_ui.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:focus/app/focus/view/global_scaffold.dart';
import 'package:things/things.dart';

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
                '21:06',
                textAlign: TextAlign.start,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const Text(
                '🌙 Domingo, 19 de janeiro',
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
            height: 12,
          ),
          BaseCard(
            BaseCardParams(
              id: 0,
              title: '😴 Falta 30min para dormir',
              subtitle: 'Que tal começar a se preparar?',
              onTap: () {},
              isOutlined: true,
            ),
          ),
          // Text(
          //   '⏱️ Agora',
          //   style: Theme.of(context).textTheme.headlineMedium,
          // ),
          // const SizedBox(
          //   height: 10,
          // ),
          // BaseCard(
          //   BaseCardParams(
          //     title: 'Resolver plano de saúde',
          //     onTap: () {},
          //     openOptions: () {},
          //     isInProgress: true,
          //   ),
          // ),
          const SizedBox(
            height: 25,
          ),
          Text(
            '⏳ Para amanhã',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(
            height: 10,
          ),
          BaseCard(
            BaseCardParams(
              id: 1,
              title: 'Colocar ripados',
              subtitle: '🏠 Casinha',
              onTap: () {},
              isDraggable: true,
            ),
          ),
          const SizedBox(
            height: 3,
          ),
          BaseCard(
            BaseCardParams(
              id: 2,
              title: 'Fazer código hackathon',
              onTap: () {},
              isDraggable: true,
            ),
          ),
          const SizedBox(
            height: 30,
          ),
          Text(
            'Você',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(
            height: 12,
          ),
          const CardShape(
            child: SizedBox(
              width: 20,
              height: 200,
            ),
          ),
        ],
      ),
    );
  }
}

class CardShape extends StatelessWidget {
  const CardShape({
    required this.child,
    super.key,
  });
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        color: AppColors.defaultCardColor,
        shape: SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius(
            cornerRadius: 10,
            cornerSmoothing: 1,
          ),
        ),

        //borderRadius: BorderRadius.circular(14),
      ),
      child: child,
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
