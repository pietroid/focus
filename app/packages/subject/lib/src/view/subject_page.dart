import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:subject/src/view/widgets/notes_panel.dart';
import 'package:subject/src/view/widgets/source_panel.dart';
import 'package:subject/subject.dart';

/// {@template subject_page}
/// Page that displays a single subject and allows content uploads.
/// {@endtemplate}
class SubjectPage extends StatelessWidget {
  /// {@macro subject_page}
  const SubjectPage({
    required this.subjectId,
    required this.uploadButtonLabel,
    required this.onHomePressed,
    super.key,
  });

  /// The unique identifier of the subject to display.
  final String subjectId;

  /// Text displayed on the upload button.
  final String uploadButtonLabel;

  /// Called when the home button is pressed.
  final VoidCallback onHomePressed;

  @override
  Widget build(BuildContext context) {
    final subject = context.select<SubjectBloc, Subject?>(
      (bloc) => bloc.state.subjects.where((s) => s.id == subjectId).firstOrNull,
    );

    if (subject == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBarDefault(
        title: subject.name,
        onHomePressed: onHomePressed,
      ),
      body: BlocProvider(
        create: (context) => SourceCubit(
          subjectId: subject.id,
          subjectRepository: context.read<SubjectRepository>(),
          sources: subject.sources,
          lastOpenedSourceId: subject.lastOpenedSource,
        ),
        child: BlocListener<SourceCubit, SourceState>(
          listenWhen: (previous, current) =>
              previous.sources != current.sources ||
              previous.selectedSourceId != current.selectedSourceId,
          listener: (context, state) {
            context.read<SubjectBloc>().add(
              SubjectUpdated(
                subject.copyWith(
                  sources: state.sources,
                  lastOpenedSource: state.selectedSourceId,
                ),
              ),
            );
          },
          child: const Row(
            children: [
              Expanded(flex: 2, child: SourcePanel()),
              Expanded(child: NotesPanel()),
            ],
          ),
        ),
      ),
    );
  }
}
