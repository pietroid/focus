import 'package:cron/app/core/thing.dart';
import 'package:cron/app/core/use_cases/thing_use_cases.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CreationBottomSheet {
  CreationBottomSheet({
    required this.thingUseCases,
  });
  final ThingUseCases thingUseCases;

  void show(
    BuildContext context, {
    Thing? existingThing,
  }) {
    showModalBottomSheet(
      useSafeArea: true,
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 24,
              top: 16,
              right: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: TextField(
              controller: TextEditingController(text: existingThing?.content),
              textInputAction: TextInputAction.go,
              onSubmitted: (value) {
                final thingToSubmit = existingThing ??
                    Thing(
                      content: value,
                      createdAt: DateTime.now(),
                      done: false,
                    );
                thingToSubmit.content = value;
                thingUseCases.addOrEditThing(
                  thing: thingToSubmit,
                );
                context.pop();
              },
              maxLines: null,
              autofocus: true,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w400,
                fontSize: 14,
              ),
              decoration: const InputDecoration(
                // TODO: we could have some nice random phrases here every time the user opens the bottom sheet
                hintText: 'Quer anotar algo?',
                border: InputBorder.none,
                hintStyle: TextStyle(
                  color: Color(0xFFB2B2B2),
                  fontWeight: FontWeight.w400,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
