part of 'creation_bottom_sheet_bloc.dart';

/// Status of the creation bottom sheet
enum CreationBottomSheetStatus {
  /// Initial status
  initial,

  /// Success status when the form is successfully submitted
  success,

  /// Failure status when there's an error
  failure,
}

/// State for [CreationBottomSheetBloc]
class CreationBottomSheetState extends Equatable {
  /// Creates a new instance of [CreationBottomSheetState]
  const CreationBottomSheetState({
    this.status = CreationBottomSheetStatus.initial,
    this.content = '',
    this.isTextFieldEmpty = true,
    this.isValueFieldVisible = false,
    this.value,
  });

  /// The current status of the bottom sheet
  final CreationBottomSheetStatus status;

  /// The content of the text field
  final String content;

  /// Whether the text field is empty
  final bool isTextFieldEmpty;

  /// Whether the value field is visible
  final bool isValueFieldVisible;

  /// The value entered in the value field
  final double? value;

  /// Creates a copy of this state with the given fields replaced
  CreationBottomSheetState copyWith({
    CreationBottomSheetStatus? status,
    String? content,
    bool? isTextFieldEmpty,
    bool? isValueFieldVisible,
    double? value,
  }) {
    return CreationBottomSheetState(
      status: status ?? this.status,
      content: content ?? this.content,
      isTextFieldEmpty: isTextFieldEmpty ?? this.isTextFieldEmpty,
      isValueFieldVisible: isValueFieldVisible ?? this.isValueFieldVisible,
      value: value ?? this.value,
    );
  }

  @override
  List<Object?> get props => [
        status,
        content,
        isTextFieldEmpty,
        isValueFieldVisible,
        value,
      ];
}
