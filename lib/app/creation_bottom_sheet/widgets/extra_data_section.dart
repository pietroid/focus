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
                label: state.extraData
                    .firstWhereOrNull(
                      (extraData) => extraData.key == 'timeDuration',
                    )
                    ?.value
                    .toString(),
                onTap: () {
                  DurationPickerPopup.show(
                    context,
                    initialDuration: const Duration(minutes: 15),
                    onDurationSelected: (duration) {
                      context.read<CreationBottomSheetBloc>().add(
                            ExtraDataAdded(
                              extraData: ExtraData(
                                key: 'timeDuration',
                                value: duration,
                              ),
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
