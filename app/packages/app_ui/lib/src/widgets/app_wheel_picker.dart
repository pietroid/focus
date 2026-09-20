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
  });

  final String title;
  final Widget wheel;
  final VoidCallback onConfirm;

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
                height: 180,
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
