import 'package:flutter/material.dart';
import 'package:focus/app/focus/widgets/creation_bottom_sheet.dart';
import 'package:focus/app/thing/data/initializer.dart';
import 'package:focus/app/thing/data/thing.dart';
import 'package:focus/app/thing/data/thing_repository.dart';
import 'package:focus/app/thing/widgets/thing_base_card.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

extension TimelyBaseCardMapper on Thing {
  BaseCardParams toBaseCardParams(BuildContext context) {
    final inProgress = parents.first.tags.contains(nowSectionTag);
    final isTimelyTask = parents.first.tags.contains(timelyTag);
    final creationBottomSheet = context.read<CreationBottomSheet>();
    return BaseCardParams(
      title: content,
      id: id,
      onTap: () {
        context.push('/thing/$id');
        // creationBottomSheet.show(
        //   context,
        //   existingThing: this,
        // );
      },
      onDoubleTap: () {
        creationBottomSheet.show(
          context,
          existingThing: this,
        );
      },
      isDone: done,
      isInProgress: inProgress,
      onDone: () {
        context.read<ThingRepository>().setAsDone(thing: this);
      },
      onUndone: () {
        context.read<ThingRepository>().setAsUndone(thing: this);
      },
      onDelete: () {
        context.read<ThingRepository>().removeThing(thing: this);
      },
      isDismissable: isTimelyTask,
      rightText: value?.formatAsMoney(),
    );
  }
}

extension MoneyFormatter on double {
  String formatAsMoney() {
    final formatter = NumberFormat.decimalPatternDigits(
      locale: 'pt_BR',
      decimalDigits: 2,
    );
    final formattedNumber = formatter.format(this);
    return '\$ $formattedNumber';
  }
}

extension MoneyFormatterText on String {
  num formatAsNumber() {
    final formatter = NumberFormat.decimalPatternDigits(
      locale: 'pt_BR',
      decimalDigits: 2,
    );
    final parsedNumber = formatter.parse(this);
    return parsedNumber;
  }
}
