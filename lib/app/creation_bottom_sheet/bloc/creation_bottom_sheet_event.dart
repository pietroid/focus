part of 'creation_bottom_sheet_bloc.dart';

/// Base event class for [CreationBottomSheetBloc]
@immutable
sealed class CreationBottomSheetEvent extends Equatable {
  /// Default constructor
  const CreationBottomSheetEvent();

  @override
  List<Object?> get props => [];
}

/// Event emitted when the content of the text field changes
class ContentChanged extends CreationBottomSheetEvent {
  /// Creates a new instance of [ContentChanged]
  const ContentChanged(this.content);

  /// The new content
  final String content;

  @override
  List<Object?> get props => [content];
}

/// Event emitted when the value field visibility is toggled
class ValueVisibilityToggled extends CreationBottomSheetEvent {
  /// Creates a new instance of [ValueVisibilityToggled]
  const ValueVisibilityToggled();
}

/// Event emitted when the value field content changes
class ValueChanged extends CreationBottomSheetEvent {
  /// Creates a new instance of [ValueChanged]
  const ValueChanged(this.valueString);

  /// The new value as a string
  final String valueString;

  @override
  List<Object?> get props => [valueString];
}

/// Event emitted when the form is submitted
class FormSubmitted extends CreationBottomSheetEvent {
  /// Creates a new instance of [FormSubmitted]
  const FormSubmitted();
}
