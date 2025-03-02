import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:focus/app/creation_bottom_sheet/widgets/field_button.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:things/things.dart';

class CreationBottomSheetWidget extends StatefulWidget {
  const CreationBottomSheetWidget({
    required this.thingRepository,
    super.key,
    this.existingThing,
    this.parentId,
  });
  final Thing? existingThing;
  final int? parentId;
  final ThingRepository thingRepository;

  @override
  State<CreationBottomSheetWidget> createState() =>
      _CreationBottomSheetWidgetState();
}

class _CreationBottomSheetWidgetState extends State<CreationBottomSheetWidget> {
  double? value;
  late final TextEditingController controller = TextEditingController(
    text: widget.existingThing?.content,
  );
  bool get isTextFieldEmpty => controller.text.trim().isEmpty;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Padding(
          padding: const EdgeInsets.only(
            left: 24,
            top: 16,
            right: 24,
            bottom: 10,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      autofocus: true,
                      controller: controller,
                      textInputAction: TextInputAction.go,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (contentString) {
                        final thingToSubmit = widget.existingThing ??
                            Thing(
                              content: contentString.capitalize(),
                              createdAt: DateTime.now(),
                              value: value,
                            );
                        thingToSubmit.content = contentString.capitalize();
                        thingToSubmit.value = value;

                        if (widget.existingThing != null) {
                          widget.thingRepository.editThing(
                            thing: thingToSubmit,
                          );
                        } else {
                          widget.thingRepository.addThing(
                            thing: thingToSubmit,
                            parentId: widget.parentId,
                          );
                        }
                        context.pop();
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
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 10),
                child: Row(
                  children: [
                    FieldButton(
                      icon: Icons.attach_money,
                      label: 'Valor',
                      disabled: isTextFieldEmpty,
                      onChanged: (valueString) {
                        setState(() {
                          value = valueString.formatAsNumber().toDouble();
                        });
                      },
                    ),
                    const SizedBox(
                      width: 6,
                    ),
                    FieldButton(
                      icon: Icons.timer_outlined,
                      label: 'Duração',
                      disabled: isTextFieldEmpty,
                      onChanged: (value) {},
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
