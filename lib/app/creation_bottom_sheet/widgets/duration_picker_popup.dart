import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class DurationPickerPopup extends StatefulWidget {
  const DurationPickerPopup({
    super.key,
    this.initialDuration,
    this.onDurationSelected,
  });
  final Duration? initialDuration;
  final void Function(Duration)? onDurationSelected;

  static void show(
    BuildContext context, {
    Duration? initialDuration,
    void Function(Duration)? onDurationSelected,
  }) {
    showDialog(
      context: context,
      builder: (context) => DurationPickerPopup(
        initialDuration: initialDuration,
        onDurationSelected: onDurationSelected,
      ),
    );
  }

  @override
  _DurationPickerPopupState createState() => _DurationPickerPopupState();
}

class _DurationPickerPopupState extends State<DurationPickerPopup> {
  late int _hours;
  late int _minutes;
  late int _seconds;

  @override
  void initState() {
    super.initState();
    final initialDuration = widget.initialDuration ?? Duration.zero;
    _hours = initialDuration.inHours;
    _minutes = initialDuration.inMinutes % 60;
    _seconds = initialDuration.inSeconds % 60;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Duration'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildNumberPicker(
                label: 'Hours',
                value: _hours,
                maxValue: 23,
                onChanged: (value) => setState(() => _hours = value),
              ),
              _buildNumberPicker(
                label: 'Minutes',
                value: _minutes,
                maxValue: 59,
                onChanged: (value) => setState(() => _minutes = value),
              ),
              _buildNumberPicker(
                label: 'Seconds',
                value: _seconds,
                maxValue: 59,
                onChanged: (value) => setState(() => _seconds = value),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final duration = Duration(
              hours: _hours,
              minutes: _minutes,
              seconds: _seconds,
            );
            widget.onDurationSelected?.call(duration);
            Navigator.of(context).pop();
          },
          child: const Text('Confirm'),
        ),
      ],
    );
  }

  Widget _buildNumberPicker({
    required String label,
    required int value,
    required int maxValue,
    required void Function(int) onChanged,
  }) {
    return Expanded(
      child: Column(
        children: [
          Text(label),
          SizedBox(
            height: 150,
            child: CupertinoPicker(
              itemExtent: 40,
              diameterRatio: 1.1,
              onSelectedItemChanged: (int index) => onChanged(index),
              scrollController: FixedExtentScrollController(initialItem: value),
              children: List.generate(
                maxValue + 1,
                (index) => Center(child: Text('$index')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CreationPopup extends StatelessWidget {
  const CreationPopup({
    required this.title,
    required this.message,
    super.key,
    this.onConfirm,
    this.onCancel,
  });
  final String title;
  final String message;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onCancel?.call();
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            onConfirm?.call();
          },
          child: const Text('Confirm'),
        ),
      ],
    );
  }

  // Helper method to show the popup
  static void show(
    BuildContext context, {
    required String title,
    required String message,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
  }) {
    showDialog(
      context: context,
      builder: (context) => CreationPopup(
        title: title,
        message: message,
        onConfirm: onConfirm,
        onCancel: onCancel,
      ),
    );
  }
}
