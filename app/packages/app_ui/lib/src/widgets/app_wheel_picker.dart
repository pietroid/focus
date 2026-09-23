import 'package:app_ui/app_ui.dart';
import 'package:flutter/cupertino.dart';

/// {@template app_wheel_picker}
/// The sheet behind a duration or an hour: one wheel and two buttons.
///
/// Cupertino's wheels rather than Material's dialogs, because both of these
/// answer the same kind of question — a number on a dial, five minutes at a
/// time — and a wheel says that while a dialog full of fields does not.
/// {@endtemplate}
abstract final class AppWheelPicker {
  /// Minutes are picked five at a time, which is also how the day is laid out.
  static const minuteInterval = 5;

  /// Asks for a length of time, starting at [initial].
  ///
  /// Resolves with what was confirmed, or null if the sheet was dismissed.
  static Future<Duration?> duration(
    BuildContext context, {
    required Duration initial,
  }) {
    var picked = initial;

    return _show<Duration>(
      context,
      title: 'Quanto tempo leva?',
      onConfirm: () => picked,
      wheel: CupertinoTimerPicker(
        mode: CupertinoTimerPickerMode.hm,
        minuteInterval: minuteInterval,
        initialTimerDuration: initial,
        onTimerDurationChanged: (value) => picked = value,
      ),
    );
  }

  /// Asks for an hour, starting at [initial] and never before [earliest].
  static Future<DateTime?> time(
    BuildContext context, {
    required DateTime initial,
    required DateTime earliest,
  }) {
    var picked = initial;

    return _show<DateTime>(
      context,
      title: 'A que horas?',
      onConfirm: () => picked,
      wheel: CupertinoDatePicker(
        mode: CupertinoDatePickerMode.time,
        minimumDate: earliest,
        initialDateTime: initial,
        minuteInterval: minuteInterval,
        use24hFormat: true,
        onDateTimeChanged: (value) => picked = value,
      ),
    );
  }

  /// Asks for a day and an hour, starting at [initial].
  ///
  /// The day is one of the next [days], picked from a row of chips rather
  /// than a wheel, because "hoje", "amanhã" and "sex 25" are how a person
  /// names a day and a date wheel is not. [earliest] only binds on the day it
  /// falls on: an hour tomorrow may be earlier on the clock than now.
  static Future<DateTime?> dayAndTime(
    BuildContext context, {
    required DateTime initial,
    required DateTime earliest,
    int days = 7,
  }) {
    return showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.bg.withValues(alpha: 0.72),
      builder: (_) => _DayAndTime(
        initial: initial,
        earliest: earliest,
        days: days,
      ),
    );
  }

  static Future<T?> _show<T>(
    BuildContext context, {
    required String title,
    required Widget wheel,
    required T Function() onConfirm,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.bg.withValues(alpha: 0.72),
      builder: (sheetContext) => _Sheet(
        title: title,
        wheel: wheel,
        onConfirm: () => Navigator.of(sheetContext).pop(onConfirm()),
      ),
    );
  }
}

class _Sheet extends StatelessWidget {
  const _Sheet({
    required this.title,
    required this.wheel,
    required this.onConfirm,
    this.height = 180,
  });

  final String title;
  final Widget wheel;
  final VoidCallback onConfirm;

  /// How tall the wheel's area is.
  final double height;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bg,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppSpacing.cardRadius),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s6,
            AppSpacing.s5,
            AppSpacing.s6,
            AppSpacing.s4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: AppTypography.title),
              SizedBox(
                height: height,
                // The wheel draws its own text, so the app's type has to be
                // handed to it rather than inherited from the sheet.
                child: CupertinoTheme(
                  data: const CupertinoThemeData(
                    brightness: Brightness.dark,
                    textTheme: CupertinoTextThemeData(
                      dateTimePickerTextStyle: TextStyle(
                        color: AppColors.ink,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  child: wheel,
                ),
              ),
              const SizedBox(height: AppSpacing.s2),
              AppButton(
                text: 'Confirmar',
                onPressed: onConfirm,
                expand: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayAndTime extends StatefulWidget {
  const _DayAndTime({
    required this.initial,
    required this.earliest,
    required this.days,
  });

  final DateTime initial;
  final DateTime earliest;
  final int days;

  @override
  State<_DayAndTime> createState() => _DayAndTimeState();
}

class _DayAndTimeState extends State<_DayAndTime> {
  static const _weekdays = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];

  late DateTime _day = _dateOf(widget.initial);
  late DateTime _picked = widget.initial;

  static DateTime _dateOf(DateTime at) => DateTime(at.year, at.month, at.day);

  DateTime get _today => _dateOf(DateTime.now());

  /// The hour on [_day], held at the same clock reading when the day changes.
  DateTime get _value => DateTime(
    _day.year,
    _day.month,
    _day.day,
    _picked.hour,
    _picked.minute,
  );

  String _label(DateTime day) {
    final offset = day.difference(_today).inDays;
    if (offset == 0) return 'Hoje';
    if (offset == 1) return 'Amanhã';

    return '${_weekdays[day.weekday - 1]} ${day.day}';
  }

  @override
  Widget build(BuildContext context) {
    final onEarliestDay = _day == _dateOf(widget.earliest);
    final value = onEarliestDay && _value.isBefore(widget.earliest)
        ? widget.earliest
        : _value;

    return _Sheet(
      title: 'Quando?',
      height: 180 + AppSpacing.s12,
      onConfirm: () => Navigator.of(context).pop(value),
      wheel: Column(
        children: [
          const SizedBox(height: AppSpacing.s3),
          SizedBox(
            height: AppSpacing.s8 + AppSpacing.s1,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (var offset = 0; offset < widget.days; offset++)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.s2),
                    child: _DayChip(
                      label: _label(_today.add(Duration(days: offset))),
                      selected: _day == _today.add(Duration(days: offset)),
                      onTap: () => setState(
                        () => _day = _today.add(Duration(days: offset)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: CupertinoDatePicker(
              // Rebuilt per day, because the earliest hour only applies on
              // the day it falls on.
              key: ValueKey(_day),
              mode: CupertinoDatePickerMode.time,
              minimumDate: onEarliestDay ? widget.earliest : null,
              initialDateTime: value,
              minuteInterval: AppWheelPicker.minuteInterval,
              use24hFormat: true,
              onDateTimeChanged: (picked) => _picked = picked,
            ),
          ),
        ],
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.fillStrong : AppColors.fill,
      borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
          child: Center(
            child: Text(
              label,
              style: AppTypography.label.copyWith(
                color: selected ? AppColors.ink : AppColors.ink2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
