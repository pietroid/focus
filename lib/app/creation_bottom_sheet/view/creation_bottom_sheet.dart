import 'package:app_ui/app_ui.dart';
import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:flutter/material.dart';
import 'package:focus/app/creation_bottom_sheet/view/creation_bottom_sheet_widget.dart';
import 'package:focus/app/creation_bottom_sheet/widgets/field_button.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:things/things.dart';

class CreationBottomSheet {
  CreationBottomSheet({
    required this.thingRepository,
  });
  final ThingRepository thingRepository;

  void show(
    BuildContext context, {
    Thing? existingThing,
    int? parentId,
  }) {
    showModalBottomSheet(
      useSafeArea: true,
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return CreationBottomSheetWidget(
          existingThing: existingThing,
          parentId: parentId,
          thingRepository: thingRepository,
        );
      },
    );
  }
}
