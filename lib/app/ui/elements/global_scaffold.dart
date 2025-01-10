import 'package:flutter/material.dart';
import 'package:focus/app/core/elements/mandala.dart';
import 'package:focus/app/ui/creation_bottom_sheet.dart';
import 'package:provider/provider.dart';

class GlobalScaffold extends StatelessWidget {
  const GlobalScaffold({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final creationBottomSheet = context.read<CreationBottomSheet>();
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: child,
        ),
      ),
      floatingActionButton: GestureDetector(
        onTap: () {
          creationBottomSheet.show(context);
        },
        child: const Mandala(),
      ),
    );
  }
}
