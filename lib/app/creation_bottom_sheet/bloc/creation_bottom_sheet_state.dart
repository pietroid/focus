part of 'creation_bottom_sheet_bloc.dart';

/// State for [CreationBottomSheetBloc]
@immutable
class CreationBottomSheetState extends Equatable {
  /// Creates a new instance of [CreationBottomSheetState]
  const CreationBottomSheetState({
    required this.content,
    required this.isNewThing,
    this.duration,
    this.status = CreationBottomSheetStatus.editing,
  });

  /// Creation status
  final CreationBottomSheetStatus status;

  /// The content of the text field
  final String content;

  final Duration? duration;

  /// Whether the thing is new
  final bool isNewThing;

  /// Whether the text field is empty
  bool get isTextFieldEmpty => content.trim().isEmpty;

  /// Creates a copy of this state with the given fields replaced
  CreationBottomSheetState copyWith({
    String? content,
    Duration? duration,
    CreationBottomSheetStatus? status,
  }) {
    return CreationBottomSheetState(
      content: content ?? this.content,
      duration: duration ?? this.duration,
      isNewThing: isNewThing,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props => [content, duration, isNewThing, status];
}

/// Status of the creation form
enum CreationBottomSheetStatus { editing, submitted }
