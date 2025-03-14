part of 'creation_bottom_sheet_bloc.dart';

/// State for [CreationBottomSheetBloc]
@immutable
class CreationBottomSheetState extends Equatable {
  /// Creates a new instance of [CreationBottomSheetState]
  const CreationBottomSheetState({
    required this.content,
    required this.extraData,
    required this.isNewThing,
    this.status = CreationBottomSheetStatus.editing,
  });

  /// Creation status
  final CreationBottomSheetStatus status;

  /// The content of the text field
  final String content;

  /// The extra data of the thing
  final ExtraData extraData;

  /// Whether the thing is new
  final bool isNewThing;

  /// Whether the text field is empty
  bool get isTextFieldEmpty => content.trim().isEmpty;

  /// Creates a copy of this state with the given fields replaced
  CreationBottomSheetState copyWith({
    String? content,
    ExtraData? extraData,
    CreationBottomSheetStatus? status,
  }) {
    return CreationBottomSheetState(
      content: content ?? this.content,
      extraData: extraData ?? this.extraData,
      isNewThing: isNewThing,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props => [content, extraData, isNewThing, status];
}

/// Status of the creation form
enum CreationBottomSheetStatus { editing, submitted }
