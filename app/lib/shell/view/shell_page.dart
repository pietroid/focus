import 'package:app_ui/app_ui.dart';
import 'package:chat/chat.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:focus/home/home.dart';
import 'package:focus/menu/menu.dart';
import 'package:focus/projects/projects.dart';
import 'package:focus/recommendations/recommendations.dart';
import 'package:go_router/go_router.dart';

/// {@template shell_page}
/// The four destinations of the app, and the orb that starts something new.
///
/// The destinations are kept alive behind an [IndexedStack] rather than
/// rebuilt on every tap: moving between them is not navigation, it is looking
/// somewhere else, and a list should be where it was left.
///
/// The orb lives here rather than on the timeline because it is the app's one
/// action from anywhere, not that screen's action.
/// {@endtemplate}
class ShellPage extends StatefulWidget {
  /// {@macro shell_page}
  const ShellPage({super.key});

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  int _index = 0;

  Future<void> _compose() async {
    final text = await AppPromptSheet.show(context);
    if (text == null || !mounted) return;

    // A new thread lands at the end of "Em breve"; the server places it. The
    // list is refetched on the way back so the card is there when the chat
    // closes.
    await context.push<void>('/chat', extra: text);
    if (mounted) {
      context.read<ThreadsBloc>().add(const ThreadsRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The bar fogs whatever runs under it, so the body runs under it.
      extendBody: true,
      body: IndexedStack(
        index: _index,
        children: const [
          HomePage(),
          ProjectsPage(),
          RecommendationsPage(),
          MenuPage(),
        ],
      ),
      bottomNavigationBar: AppBottomBar(
        currentIndex: _index,
        onSelected: (index) => setState(() => _index = index),
        center: AppOrb(onTap: _compose),
        items: const [
          AppBottomBarItem(iconData: AppIcons.timeline, label: 'Timeline'),
          AppBottomBarItem(iconData: AppIcons.projects, label: 'Projetos'),
          // "Sugestões" rather than "Recomendações": the longer word does
          // not fit a quarter of a phone's width at this size without being
          // cut, and a cut label is worse than a shorter one.
          AppBottomBarItem(
            iconData: AppIcons.recommendations,
            label: 'Sugestões',
          ),
          AppBottomBarItem(iconData: AppIcons.menu, label: 'Menu'),
        ],
      ),
    );
  }
}
