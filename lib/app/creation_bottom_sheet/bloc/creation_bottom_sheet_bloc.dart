import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:things/things.dart';

part 'creation_bottom_sheet_event.dart';
part 'creation_bottom_sheet_state.dart';

/// A bloc that manages the state of the [CreationBottomSheetWidget].
class CreationBottomSheetBloc
    extends Bloc<CreationBottomSheetEvent, CreationBottomSheetState> {
  /// Creates a new instance of [CreationBottomSheetBloc].
  CreationBottomSheetBloc({
    required ThingRepository thingRepository,
    Thing? existingThing,
    int? parentId,
  })  : _thingRepository = thingRepository,
        _existingThing = existingThing,
        _parentId = parentId,
        super(
          CreationBottomSheetState(
            content: existingThing?.content ?? '',
            isTextFieldEmpty: (existingThing?.content ?? '').isEmpty,
            value: existingThing?.value,
          ),
        ) {
    on<ContentChanged>(_onContentChanged);
    on<ValueVisibilityToggled>(_onValueVisibilityToggled);
    on<ValueChanged>(_onValueChanged);
    on<FormSubmitted>(_onFormSubmitted);
  }

  final ThingRepository _thingRepository;
  final Thing? _existingThing;
  final int? _parentId;

  void _onContentChanged(
    ContentChanged event,
    Emitter<CreationBottomSheetState> emit,
  ) {
    emit(
      state.copyWith(
        content: event.content,
        isTextFieldEmpty: event.content.trim().isEmpty,
      ),
    );
  }

  void _onValueVisibilityToggled(
    ValueVisibilityToggled event,
    Emitter<CreationBottomSheetState> emit,
  ) {
    if (state.isTextFieldEmpty) return;
    emit(state.copyWith(isValueFieldVisible: !state.isValueFieldVisible));
  }

  void _onValueChanged(
    ValueChanged event,
    Emitter<CreationBottomSheetState> emit,
  ) {
    final value = double.tryParse(event.valueString);
    emit(state.copyWith(value: value));
  }

  void _onFormSubmitted(
    FormSubmitted event,
    Emitter<CreationBottomSheetState> emit,
  ) {
    if (state.isTextFieldEmpty) return;

    final content = state.content.capitalize();
    final thingToSubmit = _existingThing ??
        Thing(
          content: content,
          createdAt: DateTime.now(),
          value: state.value,
        );

    if (_existingThing != null) {
      thingToSubmit.content = content;
      thingToSubmit.value = state.value;
      _thingRepository.editThing(thing: thingToSubmit);
    } else {
      thingToSubmit.content = content;
      _thingRepository.addThing(
        thing: thingToSubmit,
        parentId: _parentId,
      );
    }

    emit(state.copyWith(status: CreationBottomSheetStatus.success));
  }
}

/// Extension to capitalize the first letter of a string
extension StringExtension on String {
  /// Capitalizes the first letter of the string
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
