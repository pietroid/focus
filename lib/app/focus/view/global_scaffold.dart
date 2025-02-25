import 'package:flutter/material.dart';
import 'package:focus/app/focus/widgets/mandala.dart';
import 'package:focus/app/focus/widgets/creation_bottom_sheet.dart';
import 'package:go_router/go_router.dart';
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
          final currentRoute = GoRouterState.of(context).uri.toString();
          if (currentRoute.contains('thing')) {
            creationBottomSheet.show(
              context,
              parentId: int.parse(currentRoute.split('/').last),
            );
            return;
          }
          creationBottomSheet.show(context);
        },
        child: const Mandala(),
      ),
    );
  }
}
