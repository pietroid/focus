import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:focus/app/creation_bottom_sheet/bloc/creation_bottom_sheet_bloc.dart';
import 'package:focus/app/creation_bottom_sheet/widgets/field_button.dart';

class ExtraDataSection extends StatelessWidget {
  const ExtraDataSection({
    required this.isActive,
    super.key,
  });
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 10),
      child: Row(
        children: [
          FieldButton(
            icon: Icons.attach_money,
            label: 'Valor',
            disabled: isActive,
            onTap: () {
              // context.read<CreationBottomSheetBloc>().add(
              //       const ValueVisibilityToggled(),
              //     );
            },
          ),
          const SizedBox(
            width: 6,
          ),
          FieldButton(
            icon: Icons.timer_outlined,
            label: 'Duração',
            disabled: isActive,
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
