import 'package:equatable/equatable.dart';
import 'package:subject/subject.dart';

/// {@template source_upload_status}
/// Possible statuses for source operations.
/// {@endtemplate}
enum SourceStatus {
  /// Initial state before any operation.
  initial,

  /// A file is being uploaded.
  uploading,

  /// An error occurred during upload.
  failure,
}

/// {@template source_state}
/// State for the source panel.
/// {@endtemplate}
class SourceState extends Equatable {
  /// {@macro source_state}
  const SourceState({
    this.status = SourceStatus.initial,
    this.sources = const [],
    this.selectedSourceId,
    this.errorMessage,
  });

  /// Current status of source operations.
  final SourceStatus status;

  /// List of sources attached to the subject.
  final List<Source> sources;

  /// Identifier of the currently selected source.
  final String? selectedSourceId;

  /// Error message when [status] is [SourceStatus.failure].
  final String? errorMessage;

  /// Whether a file is currently being uploaded.
  bool get isUploading => status == SourceStatus.uploading;

  /// The currently selected source, if any.
  Source? get selectedSource {
    if (selectedSourceId == null) return null;
    return sources.where((s) => s.id == selectedSourceId).firstOrNull;
  }

  /// Whether the panel has any sources to display.
  bool get hasSources => sources.isNotEmpty;

  /// Creates a copy of this state with the given fields replaced.
  SourceState copyWith({
    SourceStatus? status,
    List<Source>? sources,
    String? selectedSourceId,
    String? errorMessage,
  }) {
    return SourceState(
      status: status ?? this.status,
      sources: sources ?? this.sources,
      selectedSourceId: selectedSourceId ?? this.selectedSourceId,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, sources, selectedSourceId, errorMessage];
}
