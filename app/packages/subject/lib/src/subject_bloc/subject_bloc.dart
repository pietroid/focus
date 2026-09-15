import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:subject/subject.dart';

part 'subject_event.dart';
part 'subject_state.dart';

/// {@template subject_bloc}
/// Manages the list of subjects and subject creation.
/// {@endtemplate}
class SubjectBloc extends Bloc<SubjectEvent, SubjectState> {
  /// {@macro subject_bloc}
  SubjectBloc({required SubjectRepository subjectRepository})
      // The public constructor parameter name differs from the private field,
      // so an initializing formal cannot be used here.
      // ignore: prefer_initializing_formals
      : _subjectRepository = subjectRepository,
        super(const SubjectState()) {
    on<SubjectsRequested>(_onSubjectsRequested);
    on<SubjectCreated>(_onSubjectCreated);
    on<SubjectUpdated>(_onSubjectUpdated);
  }

  final SubjectRepository _subjectRepository;

  Future<void> _onSubjectsRequested(
    SubjectsRequested event,
    Emitter<SubjectState> emit,
  ) async {
    emit(state.copyWith(status: SubjectStatus.loading));

    try {
      final subjects = await _subjectRepository.getSubjects();
      emit(
        state.copyWith(
          status: SubjectStatus.loaded,
          subjects: subjects,
        ),
      );
    } on Exception catch (error, stackTrace) {
      emit(
        state.copyWith(
          status: SubjectStatus.failure,
          errorMessage: error.toString(),
        ),
      );
      addError(error, stackTrace);
    }
  }

  Future<void> _onSubjectCreated(
    SubjectCreated event,
    Emitter<SubjectState> emit,
  ) async {
    emit(state.copyWith(status: SubjectStatus.creating));

    try {
      final subject = await _subjectRepository.createSubject(event.name);
      emit(
        state.copyWith(
          status: SubjectStatus.loaded,
          subjects: [...state.subjects, subject],
          createdSubject: subject,
        ),
      );
    } on Exception catch (error, stackTrace) {
      emit(
        state.copyWith(
          status: SubjectStatus.failure,
          errorMessage: error.toString(),
        ),
      );
      addError(error, stackTrace);
    }
  }

  void _onSubjectUpdated(
    SubjectUpdated event,
    Emitter<SubjectState> emit,
  ) {
    final updatedSubjects = state.subjects
        .map(
          (subject) => subject.id == event.subject.id ? event.subject : subject,
        )
        .toList();

    emit(state.copyWith(subjects: updatedSubjects));
  }
}
