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
            content: existingThing?.content ?? '',
            extraData: existingThing != null
                ? extraDataMapper.extractExtraDataFromThing(existingThing)
                : [],
          ),
        ) {
    on<ContentChanged>(_onContentChanged);
    on<CreationSubmitted>(_onCreationSubmitted);
    on<ExtraDataAdded>(_onExtraDataAdded);
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
      ),
    );
  }

  void _onCreationSubmitted(
    CreationSubmitted event,
    Emitter<CreationBottomSheetState> emit,
  ) {
    if (state.isTextFieldEmpty) return;

    final content = state.content.capitalize();
    final thingToSubmit = _existingThing ??
        Thing(
          content: content,
          createdAt: DateTime.now(),
        );

    if (_existingThing != null) {
      thingToSubmit.content = content;
      _thingRepository.editThing(thing: thingToSubmit);
    } else {
      thingToSubmit.content = content;
      _thingRepository.addThing(
        thing: thingToSubmit,
        parentId: _parentId,
      );
    }

    emit(
      state.copyWith(
        status: CreationBottomSheetStatus.submitted,
      ),
    );
  }

  void _onExtraDataAdded(
    ExtraDataAdded event,
    Emitter<CreationBottomSheetState> emit,
  ) {
    emit(
      state.copyWith(
        extraData: List.of(state.extraData)..add(event.extraData),
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
