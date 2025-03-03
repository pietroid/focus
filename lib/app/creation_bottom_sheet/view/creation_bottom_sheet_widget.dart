import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:focus/app/creation_bottom_sheet/bloc/creation_bottom_sheet_bloc.dart';
import 'package:focus/app/creation_bottom_sheet/widgets/field_button.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:things/things.dart';

class CreationBottomSheetWidget extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CreationBottomSheetBloc(
        thingRepository: thingRepository,
        existingThing: existingThing,
        parentId: parentId,
      ),
      child: const _CreationBottomSheetView(),
    );
  }
}

class _CreationBottomSheetView extends StatefulWidget {
  const _CreationBottomSheetView();

  @override
  State<_CreationBottomSheetView> createState() =>
      _CreationBottomSheetViewState();
}

class _CreationBottomSheetViewState extends State<_CreationBottomSheetView> {
  late final TextEditingController _contentController = TextEditingController();
  late final TextEditingController _valueController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final bloc = context.read<CreationBottomSheetBloc>();
    final state = bloc.state;
    _contentController.text = state.content;
    _contentController.addListener(() {
      bloc.add(ContentChanged(_contentController.text));
    });
    _valueController.addListener(() {
      if (_valueController.text.isNotEmpty) {
        //bloc.add(ValueChanged(_valueController.text));
      }
    });
  }

  @override
  void dispose() {
    _contentController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CreationBottomSheetBloc, CreationBottomSheetState>(
      listenWhen: (previous, current) =>
          previous.status != current.status &&
          current.status == CreationBottomSheetStatus.success,
      listener: (context, state) {
        if (state.status == CreationBottomSheetStatus.success) {
          context.pop();
        }
      },
      builder: (context, state) {
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
                          controller: _contentController,
                          textInputAction: TextInputAction.go,
                          onSubmitted: (_) {
                            context.read<CreationBottomSheetBloc>().add(
                                  const FormSubmitted(),
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
                        ),
                      ),
                      if (state.isValueFieldVisible)
                        Expanded(
                          child: TextField(
                            autofocus: true,
                            controller: _valueController,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            style: GoogleFonts.onest(
                              fontSize: 14,
                              color: Colors.white,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Valor',
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
                          disabled: state.isTextFieldEmpty,
                          onTap: () {
                            if (!state.isTextFieldEmpty) {
                              context.read<CreationBottomSheetBloc>().add(
                                    const ValueVisibilityToggled(),
                                  );
                            }
                          },
                        ),
                        const SizedBox(
                          width: 6,
                        ),
                        FieldButton(
                          icon: Icons.timer_outlined,
                          label: 'Duração',
                          disabled: state.isTextFieldEmpty,
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
