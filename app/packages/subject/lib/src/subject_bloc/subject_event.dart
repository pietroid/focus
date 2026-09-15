part of 'subject_bloc.dart';

/// {@template subject_event}
/// Base class for all subject events.
/// {@endtemplate}
abstract class SubjectEvent extends Equatable {
  /// {@macro subject_event}
  const SubjectEvent();

  @override
  List<Object?> get props => [];
}

/// {@template subjects_requested}
/// Requested when the subjects list should be loaded.
/// {@endtemplate}
class SubjectsRequested extends SubjectEvent {
  /// {@macro subjects_requested}
  const SubjectsRequested();
}

/// {@template subject_created}
/// Requested when a new subject should be created.
/// {@endtemplate}
class SubjectCreated extends SubjectEvent {
  /// {@macro subject_created}
  const SubjectCreated(this.name);

  /// The name of the subject to create.
  final String name;

  @override
  List<Object?> get props => [name];
}

/// {@template subject_updated}
/// Requested when an existing subject should be replaced in the list.
/// {@endtemplate}
class SubjectUpdated extends SubjectEvent {
  /// {@macro subject_updated}
  const SubjectUpdated(this.subject);

  /// The updated subject.
  final Subject subject;

  @override
  List<Object?> get props => [subject];
}
