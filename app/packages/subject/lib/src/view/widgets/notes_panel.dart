import 'package:app_ui/app_ui.dart';

/// {@template notes_panel}
/// A panel for writing and viewing subject notes.
/// {@endtemplate}
class NotesPanel extends StatelessWidget {
  /// {@macro notes_panel}
  const NotesPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: AppTextEditor(
        hintText: 'Write your notes here...',
      ),
    );
  }
}
