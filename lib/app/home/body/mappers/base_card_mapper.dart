import 'package:app_ui/app_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:focus/app/creation_bottom_sheet/view/creation_bottom_sheet.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:things/things.dart';

class BaseCardMapper {
  BaseCardParams toBaseCardParams({
    required BuildContext context,
    required Thing thing,
  }) {
    final inProgress = thing.parents.first.tags.contains(nowSectionTag);
    final isTimelyTask = thing.parents.first.tags.contains(timelyTag);
    final creationBottomSheet = context.read<CreationBottomSheet>();

    return BaseCardParams(
      title: thing.content,
      id: thing.id,
      onTap: () {
        context.push('/thing/${thing.id}');
      },
      onDoubleTap: () {
        creationBottomSheet.show(
          context,
          existingThing: thing,
        );
      },
      isDone: thing.done,
      isInProgress: inProgress,
      onDone: () {
        context.read<ThingRepository>().setAsDone(thing: thing);
      },
      onUndone: () {
        context.read<ThingRepository>().setAsUndone(thing: thing);
      },
      onDelete: () {
        context.read<ThingRepository>().removeThing(thing: thing);
      },
      isDismissable: isTimelyTask,
      rightText: thing.value?.formatAsMoney(),
    );
  }
}
