import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:subject/subject.dart';

/// {@template source_cubit}
/// Manages the source list, selection, and upload flow for a subject.
/// {@endtemplate}
class SourceCubit extends Cubit<SourceState> {
  /// {@macro source_cubit}
  SourceCubit({
    required this.subjectId,
    required this.subjectRepository,
    required List<Source> sources,
    required String? lastOpenedSourceId,
  }) : super(
          SourceState(
            sources: sources,
            selectedSourceId: _resolveSelectedSourceId(
              sources: sources,
              lastOpenedSourceId: lastOpenedSourceId,
            ),
          ),
        );

  /// The identifier of the subject that owns the sources.
  final String subjectId;

  /// Repository used to upload files and update subject metadata.
  final SubjectRepository subjectRepository;

  static String? _resolveSelectedSourceId({
    required List<Source> sources,
    required String? lastOpenedSourceId,
  }) {
    if (lastOpenedSourceId != null &&
        sources.any((source) => source.id == lastOpenedSourceId)) {
      return lastOpenedSourceId;
    }
    return sources.firstOrNull?.id;
  }

  /// Selects a source by [sourceId] and updates the last opened source on the
  /// backend.
  Future<void> selectSource(String sourceId) async {
    if (sourceId == state.selectedSourceId) return;

    emit(state.copyWith(selectedSourceId: sourceId));

    try {
      await subjectRepository.updateLastOpenedSource(
        subjectId: subjectId,
        sourceId: sourceId,
      );
    } on Exception catch (_) {
      // Keep the local selection even if the backend update fails.
    }
  }

  /// Opens the system file picker for PDFs and uploads the selected file.
  Future<void> pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      emit(
        state.copyWith(
          status: SourceStatus.failure,
          errorMessage: 'Selected file is empty',
        ),
      );
      return;
    }

    emit(state.copyWith(status: SourceStatus.uploading));

    try {
      final source = await subjectRepository.uploadSource(
        subjectId: subjectId,
        bytes: bytes,
        filename: file.name,
      );

      final updatedSources = [...state.sources, source];
      emit(
        state.copyWith(
          status: SourceStatus.initial,
          sources: updatedSources,
          selectedSourceId: source.id,
        ),
      );
    } on Exception catch (error) {
      emit(
        state.copyWith(
          status: SourceStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  /// Adds an overlay to the currently selected source.
  Future<void> addOverlay({
    required double x,
    required double y,
    required String text,
    required String color,
  }) async {
    final sourceId = state.selectedSourceId;
    if (sourceId == null) return;

    try {
      final updatedSubject = await subjectRepository.addOverlay(
        subjectId: subjectId,
        sourceId: sourceId,
        x: x,
        y: y,
        text: text,
        color: color,
      );

      final updatedSource = updatedSubject.sources
          .where((source) => source.id == sourceId)
          .firstOrNull;

      if (updatedSource == null) return;

      final updatedSources = state.sources.map((source) {
        return source.id == sourceId ? updatedSource : source;
      }).toList();

      emit(state.copyWith(sources: updatedSources));
    } on Exception catch (error) {
      emit(
        state.copyWith(
          errorMessage: 'Failed to add overlay: $error',
        ),
      );
    }
  }
}
