import 'package:flutter/material.dart';
import 'package:focus/app/focus/widgets/mandala.dart';
import 'package:focus/app/creation_bottom_sheet/view/creation_bottom_sheet.dart';
import 'package:focus/app/creation_bottom_sheet/launcher/creation_bottom_sheet_launcher.dart';
import 'package:provider/provider.dart';

class GlobalScaffold extends StatelessWidget {
  const GlobalScaffold({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: child,
        ),
      ),
      floatingActionButton: GestureDetector(
        onTap: () {
          CreationBottomSheetLauncher(
            creationBottomSheet: context.read<CreationBottomSheet>(),
          ).launchFromRoute(context);
        },
        child: const Mandala(),
      ),
    );
  }
}
