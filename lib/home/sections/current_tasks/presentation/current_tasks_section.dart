import 'package:cron/core/ui/base_card.dart';
import 'package:cron/home/sections/core/home_section.dart';
import 'package:flutter/material.dart';

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
