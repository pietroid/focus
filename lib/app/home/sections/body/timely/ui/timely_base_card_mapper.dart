import 'package:flutter/material.dart';
import 'package:focus/app/thing/data/initializer.dart';
import 'package:focus/app/thing/data/thing.dart';
import 'package:focus/app/thing/data/thing_repository.dart';
import 'package:focus/app/thing/ui/thing_base_card.dart';
import 'package:focus/app/focus/core/creation_bottom_sheet.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

extension TimelyBaseCardMapper on Thing {
  BaseCardParams toBaseCardParams(BuildContext context) {
    final inProgress = parents.first.tags.contains(nowSectionTag);
    final creationBottomSheet = context.read<CreationBottomSheet>();
    return BaseCardParams(
      title: content,
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
      hasBeenDismissed: done,
      isInProgress: inProgress,
      onChanged: () {
        if (done) {
          context.read<ThingRepository>().setAsUndone(thing: this);
          return;
        }
        context.read<ThingRepository>().setAsDone(thing: this);
      },
      openOptions: () {
        // context.push('/thing/$id');
      },
      rightText: value?.formatAsMoney(),
    );
  }
}

extension MoneyFormatter on double {
  String formatAsMoney() {
    final formatter = NumberFormat.decimalPatternDigits(
      decimalDigits: 2,
    );
    final formattedNumber = formatter.parse(toString());
    return '\$ $formattedNumber';
  }
}
