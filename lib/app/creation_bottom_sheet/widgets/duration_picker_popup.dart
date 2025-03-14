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
    final textTheme = Theme.of(context).textTheme;
    return AlertDialog(
      title: Text('Duração', style: textTheme.headlineMedium),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildNumberPicker(
                label: 'Horas',
                value: _hours,
                maxValue: 23,
                onChanged: (value) => setState(() => _hours = value),
              ),
              _buildNumberPicker(
                label: 'Minutos',
                value: _minutes,
                maxValue: 59,
                onChanged: (value) => setState(() => _minutes = value),
              ),
              _buildNumberPicker(
                label: 'Segundos',
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
          child: Text('Cancelar', style: textTheme.bodyMedium),
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
          child: Text('Confirmar', style: textTheme.bodyMedium),
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
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
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
