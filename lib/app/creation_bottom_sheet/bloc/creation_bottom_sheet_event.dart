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

/// Event emitted when the form is submitted
class CreationSubmitted extends CreationBottomSheetEvent {
  /// Creates a new instance of [CreationSubmitted]
  const CreationSubmitted();
}

class OnDurationEdited extends CreationBottomSheetEvent {
  const OnDurationEdited(this.duration);

  final Duration? duration;

  @override
  List<Object?> get props => [duration];
}
