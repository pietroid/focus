class ExtraData {
  // Value in money units
  double? value;

  // Duration of the thing
  Duration? duration;

  ExtraData({
    this.value,
    this.duration,
  });

  ExtraData copyWith({
    double? value,
    Duration? duration,
  }) {
    return ExtraData(
      value: value ?? this.value,
      duration: duration ?? this.duration,
    );
  }
}
