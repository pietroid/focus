import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:focus/examples/widget/widget_without_scaffold/example_class_a.dart';
import 'package:focus/examples/widget/widget_without_scaffold/example_class_b.dart';

class ExampleWidget extends StatefulWidget {
  const ExampleWidget({
    required this.exampleClassB,
    super.key,
  });
  final ExampleClassB exampleClassB;

  @override
  State<ExampleWidget> createState() => _ExampleWidgetState();
}

class _ExampleWidgetState extends State<ExampleWidget> {
  @override
  Widget build(BuildContext context) {
    final exampleClassA = context.read<ExampleClassA>();
    final exampleClassB = widget.exampleClassB;
    final width = MediaQuery.of(context).size.width;
    return Container();
  }
}
