import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:focus/examples/widget/widget_with_scaffold/example_class_a.dart';
import 'package:focus/examples/widget/widget_with_scaffold/example_class_b.dart';

class ExampleWidgetWithScaffold extends StatefulWidget {
  const ExampleWidgetWithScaffold({
    required this.exampleClassB,
    super.key,
  });
  final ExampleClassB exampleClassB;

  @override
  State<ExampleWidgetWithScaffold> createState() =>
      _ExampleWidgetWithScaffoldState();
}

class _ExampleWidgetWithScaffoldState extends State<ExampleWidgetWithScaffold> {
  @override
  Widget build(BuildContext context) {
    final exampleClassA = context.read<ExampleClassA>();
    final exampleClassB = widget.exampleClassB;
    final width = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Example Widget'),
      ),
      body: Container(),
    );
  }
}
