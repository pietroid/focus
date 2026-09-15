part of 'subject_bloc.dart';

/// {@template subject_status}
/// Possible statuses for subject operations.
/// {@endtemplate}
enum SubjectStatus {
  /// Initial state before any operation.
  initial,

  /// Subjects are being loaded.
  loading,

  /// Subjects have been loaded successfully.
  loaded,

  /// A new subject is being created.
  creating,

  /// An error occurred.
  failure,
}

/// {@template subject_state}
/// State for the [SubjectBloc].
/// {@endtemplate}
class SubjectState extends Equatable {
  /// {@macro subject_state}
  const SubjectState({
    this.status = SubjectStatus.initial,
    this.subjects = const [],
    this.createdSubject,
    this.errorMessage,
  });

  /// Current status of subject operations.
  final SubjectStatus status;

  /// List of loaded subjects.
  final List<Subject> subjects;

  /// The most recently created subject, if any.
  final Subject? createdSubject;

  /// Error message when [status] is [SubjectStatus.failure].
  final String? errorMessage;

  /// Whether subjects are currently being loaded.
  bool get isLoading => status == SubjectStatus.loading;

  /// Whether a subject is currently being created.
  bool get isCreating => status == SubjectStatus.creating;

  /// Creates a copy of this state with the given fields replaced.
  SubjectState copyWith({
    SubjectStatus? status,
    List<Subject>? subjects,
    Subject? createdSubject,
    String? errorMessage,
  }) {
    return SubjectState(
      status: status ?? this.status,
      subjects: subjects ?? this.subjects,
      createdSubject: createdSubject ?? this.createdSubject,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        subjects,
        createdSubject,
        errorMessage,
      ];
}
