import 'package:flutter/widgets.dart';
import 'package:focus/app/creation_bottom_sheet/view/creation_bottom_sheet.dart';
import 'package:go_router/go_router.dart';

class CreationBottomSheetLauncher {
  const CreationBottomSheetLauncher({
    required this.creationBottomSheet,
  });

  final CreationBottomSheet creationBottomSheet;

  void launchFromRoute(BuildContext context) {
    final currentRoute = GoRouterState.of(context).uri.toString();
    if (currentRoute.contains('thing')) {
      creationBottomSheet.show(
        context,
        parentId: int.parse(currentRoute.split('/').last),
      );
      return;
    }
    creationBottomSheet.show(context);
  }
}
