part of 'creation_bottom_sheet_bloc.dart';

/// State for [CreationBottomSheetBloc]
class CreationBottomSheetState extends Equatable {
  /// Creates a new instance of [CreationBottomSheetState]
  const CreationBottomSheetState({
    this.content = '',
    this.extraData = const [],
    this.status = CreationBottomSheetStatus.editing,
  });

  /// Creation status
  final CreationBottomSheetStatus status;

  /// The content of the text field
  final String content;

  /// The extra data associated with the content
  final List<ExtraData> extraData;

  /// Whether the text field is empty
  bool get isTextFieldEmpty => content.trim().isEmpty;

  /// Creates a copy of this state with the given fields replaced
  CreationBottomSheetState copyWith({
    String? content,
    List<ExtraData>? extraData,
    CreationBottomSheetStatus? status,
  }) =>
      CreationBottomSheetState(
        content: content ?? this.content,
        extraData: extraData ?? this.extraData,
        status: status ?? this.status,
      );

  @override
  List<Object?> get props => [content, extraData, status];
}

class ExtraData {
  ExtraData({
    required this.key,
    this.value,
  });

  String key;
  Object? value;
}

/// Status of the creation form
enum CreationBottomSheetStatus { editing, submitted }
