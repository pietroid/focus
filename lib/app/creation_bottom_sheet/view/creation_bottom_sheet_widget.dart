import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:focus/app/creation_bottom_sheet/bloc/creation_bottom_sheet_bloc.dart';
import 'package:focus/app/creation_bottom_sheet/mapper/extra_data_mapper.dart';
import 'package:focus/app/creation_bottom_sheet/widgets/extra_data_section.dart';
import 'package:focus/app/creation_bottom_sheet/widgets/text_field_section.dart';
import 'package:go_router/go_router.dart';
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
        extraDataMapper: ExtraDataMapper(),
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

  @override
  void initState() {
    super.initState();
    final bloc = context.read<CreationBottomSheetBloc>();
    final state = bloc.state;
    _contentController.text = state.content;
    _contentController.addListener(() {
      bloc.add(ContentChanged(_contentController.text));
    });
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CreationBottomSheetBloc, CreationBottomSheetState>(
      listenWhen: (previous, current) =>
          previous.status != current.status &&
          current.status == CreationBottomSheetStatus.submitted,
      listener: (context, state) {
        if (state.status == CreationBottomSheetStatus.submitted) {
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
                  TextFieldSection(
                    contentController: _contentController,
                  ),
                  ExtraDataSection(
                    isActive: state.isTextFieldEmpty,
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
