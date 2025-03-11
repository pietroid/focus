import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:focus/app/creation_bottom_sheet/bloc/creation_bottom_sheet_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

class TextFieldSection extends StatelessWidget {
  const TextFieldSection({
    required this.contentController,
    super.key,
  });

  final TextEditingController contentController;

  @override
  Widget build(BuildContext context) {
    return TextField(
      autofocus: true,
      controller: contentController,
      textInputAction: TextInputAction.go,
      onSubmitted: (_) {
        context.read<CreationBottomSheetBloc>().add(
              const CreationSubmitted(),
            );
      },
      maxLines: null,
      style: GoogleFonts.onest(
        fontSize: 14,
        color: Colors.white,
      ),
      decoration: const InputDecoration(
        hintText: 'Quer anotar algo?',
        border: InputBorder.none,
      ),
    );
  }
}
