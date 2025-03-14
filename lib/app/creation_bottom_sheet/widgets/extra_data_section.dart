import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:focus/app/creation_bottom_sheet/bloc/creation_bottom_sheet_bloc.dart';
import 'package:focus/app/creation_bottom_sheet/widgets/duration_picker_popup.dart';
import 'package:focus/app/creation_bottom_sheet/widgets/field_button.dart';

class ExtraDataSection extends StatelessWidget {
  const ExtraDataSection({
    required this.isActive,
    super.key,
  });
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CreationBottomSheetBloc, CreationBottomSheetState>(
      buildWhen: (previous, current) => previous.extraData != current.extraData,
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 10),
          child: Row(
            children: [
              FieldButton(
                icon: Icons.attach_money,
                disabled: isActive,
                onTap: () {},
              ),
              const SizedBox(
                width: 6,
              ),
              FieldButton(
                icon: Icons.timer_outlined,
                disabled: isActive,
                label: state.extraData.duration?.formattedDuration,
                onTap: () {
                  DurationPickerPopup.show(
                    context,
                    initialDuration:
                        state.extraData.duration ?? const Duration(minutes: 15),
                    onDurationSelected: (duration) {
                      context.read<CreationBottomSheetBloc>().add(
                            OnDurationEdited(
                              duration,
                            ),
                          );
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

extension on Duration {
  String get formattedDuration {
    if (inMinutes < 60) {
      return '$inMinutes min';
    }
    final hours = inHours;
    final minutes = inMinutes.remainder(60).toString().padLeft(2, '0');
    return '${hours}h$minutes';
  }
}
