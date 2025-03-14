import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:focus/app/creation_bottom_sheet/mapper/extra_data_mapper.dart';
import 'package:focus/app/creation_bottom_sheet/view/creation_bottom_sheet_widget.dart';
import 'package:things/things.dart';

part 'creation_bottom_sheet_event.dart';
part 'creation_bottom_sheet_state.dart';

/// A bloc that manages the state of the [CreationBottomSheetWidget].
class CreationBottomSheetBloc
    extends Bloc<CreationBottomSheetEvent, CreationBottomSheetState> {
  /// Creates a new instance of [CreationBottomSheetBloc].
  CreationBottomSheetBloc({
    required ThingRepository thingRepository,
    required ExtraDataMapper extraDataMapper,
    Thing? existingThing,
    int? parentId,
  })  : _thingRepository = thingRepository,
        _existingThing = existingThing,
        _parentId = parentId,
        super(
          CreationBottomSheetState(
            isNewThing: existingThing == null,
            content: existingThing?.content ?? '',
            extraData: existingThing?.extraData ?? ExtraData(),
          ),
        ) {
    on<ContentChanged>(_onContentChanged);
    on<CreationSubmitted>(_onCreationSubmitted);
    on<OnDurationEdited>(_onDurationEdited);
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
        content: event.content.capitalize(),
      ),
    );
  }

  void _onCreationSubmitted(
    CreationSubmitted event,
    Emitter<CreationBottomSheetState> emit,
  ) {
    if (state.isTextFieldEmpty) return;
    if (state.isNewThing) {
      final thing = Thing(
        content: state.content,
        extraData: state.extraData,
        createdAt: DateTime.now(),
      );
      _thingRepository.addThing(
        thing: thing,
        parentId: _parentId,
      );
    } else {
      _existingThing?.content = state.content;
      _existingThing?.extraData = state.extraData;
      _thingRepository.editThing(thing: _existingThing!);
    }

    emit(
      state.copyWith(
        status: CreationBottomSheetStatus.submitted,
      ),
    );
  }

  void _onDurationEdited(
    OnDurationEdited event,
    Emitter<CreationBottomSheetState> emit,
  ) {
    emit(
      state.copyWith(
        extraData: state.extraData.copyWith(
          duration: event.duration,
        ),
      ),
    );
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
