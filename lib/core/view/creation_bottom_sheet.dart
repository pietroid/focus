import 'package:cron/core/domain/note.dart';
import 'package:cron/core/domain/use_cases/note_use_cases.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CreationBottomSheet {
  CreationBottomSheet({
    required this.noteUseCases,
  });
  final NoteUseCases noteUseCases;

  void show(
    BuildContext context, {
    Note? existingNote,
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
              controller: TextEditingController(text: existingNote?.content),
              textInputAction: TextInputAction.go,
              onSubmitted: (value) {
                final noteToSubmit = existingNote ??
                    Note(
                      content: value,
                      createdAt: DateTime.now(),
                    );
                noteToSubmit.content = value;
                noteUseCases.addOrEditNote(
                  note: noteToSubmit,
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
