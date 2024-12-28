import 'package:flutter/material.dart';

class GlobalScaffold extends StatelessWidget {
  const GlobalScaffold({
    required this.child,
    this.floatingActionButton,
    super.key,
  });

  final Widget child;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: child,
        ),
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}
