import 'package:app_ui/app_ui.dart';

/// {@template projects_page}
/// Projetos. The screen is not built yet; the destination is, so the bar has
/// somewhere to go.
/// {@endtemplate}
class ProjectsPage extends StatelessWidget {
  /// {@macro projects_page}
  const ProjectsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s6,
          AppSpacing.s5,
          AppSpacing.s6,
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Projetos', style: AppTypography.headline),
            const SizedBox(height: AppSpacing.s5),
            Text('Em breve.', style: AppTypography.label),
          ],
        ),
      ),
    );
  }
}
