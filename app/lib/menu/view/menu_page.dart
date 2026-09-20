import 'package:app_ui/app_ui.dart';

/// {@template menu_page}
/// Everything that is not one of the three lists: for now, the things that
/// have been put away.
/// {@endtemplate}
class MenuPage extends StatelessWidget {
  /// {@macro menu_page}
  const MenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppSpacing.maxContentWidth,
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s6,
              AppSpacing.s5,
              AppSpacing.s6,
              // Room under the last row so the bar never covers it.
              AppSpacing.s16 + AppSpacing.s12,
            ),
            children: [
              Text('Menu', style: AppTypography.headline),
              const SizedBox(height: AppSpacing.s5),
              const AppListItem(
                title: 'Itens arquivados',
                iconData: AppIcons.archive,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
