import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:flutter/material.dart';
import 'package:focus/app/home/sections/body/body/core/body.dart';
import 'package:focus/app/home/sections/body/timely/ui/timely_base_card_mapper.dart';
import 'package:focus/app/thing/data/thing.dart';
import 'package:focus/app/thing/data/thing_repository.dart';
import 'package:focus/app/app/ui/app_colors.dart';
import 'package:focus/app/common_infrastructure/ui/string_formatter.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

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
    final controller = TextEditingController(text: existingThing?.content);
    showModalBottomSheet(
      useSafeArea: true,
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return BottomSheetContent(
          controller: controller,
          existingThing: existingThing,
          parentId: parentId,
          thingRepository: thingRepository,
        );
      },
    );
  }
}

class BottomSheetContent extends StatefulWidget {
  const BottomSheetContent({
    required this.controller,
    required this.thingRepository,
    super.key,
    this.existingThing,
    this.parentId,
  });
  final Thing? existingThing;
  final int? parentId;
  final TextEditingController controller;
  final ThingRepository thingRepository;

  @override
  State<BottomSheetContent> createState() => _BottomSheetContentState();
}

class _BottomSheetContentState extends State<BottomSheetContent> {
  bool hasMoreOptions = false;
  double? value;

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
                      controller: widget.controller,
                      textInputAction: TextInputAction.go,
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
                        // TODO: we could have some nice random phrases here every time the user opens the bottom sheet
                        hintText: 'Quer anotar algo?',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  GestureDetector(
                    child: Icon(
                      hasMoreOptions
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: AppColors.primaryColor,
                    ),
                    onTap: () {
                      setState(() {
                        hasMoreOptions = !hasMoreOptions;
                      });
                    },
                  ),
                ],
              ),
              if (hasMoreOptions)
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 10),
                  child: Row(
                    children: [
                      EditableField(
                        icon: Icons.attach_money,
                        label: 'Valor',
                        onChanged: (valueString) {
                          setState(() {
                            value = valueString.formatAsNumber().toDouble();
                          });
                        },
                      ),
                      const SizedBox(
                        width: 6,
                      ),
                      EditableField(
                        icon: Icons.timer_outlined,
                        label: 'Horário',
                        onChanged: (value) {},
                      ),
                      const SizedBox(
                        width: 6,
                      ),
                      EditableField(
                        icon: Icons.timer_outlined,
                        label: 'Duração',
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

class EditableField extends StatelessWidget {
  const EditableField({
    required this.icon,
    required this.label,
    required this.onChanged,
    super.key,
  });
  final IconData icon;
  final String label;
  final void Function(String value) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(20)),
        color: AppColors.defaultCardColor,
      ),
      child: Padding(
        padding: const EdgeInsets.only(
          left: 8,
          right: 12,
          top: 8,
          bottom: 8,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
            ),
            const SizedBox(
              width: 4,
            ),
            IntrinsicWidth(
              child: TextField(
                onChanged: onChanged,
                keyboardType: TextInputType.number,
                style: GoogleFonts.onest(
                  fontSize: 14,
                  color: Colors.white,
                ),
                inputFormatters: [
                  CurrencyTextInputFormatter.currency(
                    symbol: '',
                    locale: 'pt_BR',
                  ),
                ],
                textInputAction: TextInputAction.go,
                cursorHeight: 12,
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.zero,
                  hintText: label,
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
