import 'package:flutter/material.dart';
import 'package:focus/app/core/home/sections/core/home_section.dart';
import 'package:focus/app/ui/base_card.dart';

class CurrentTasksSection extends StatelessWidget {
  const CurrentTasksSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const HomeSection(
      mustRender: true,
      title: '⏳ Agora',
      content: BaseCardContent(
        title: 'Criar a tela de login',
        subtitle: '16h00 - 18h00',
        color: Color.fromARGB(255, 0, 72, 1),
        loadingProgress: 0.5,
      ),
    );
  }
}
