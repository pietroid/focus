import 'package:flutter/material.dart';
import 'package:focus/app/core/home/core/sections/timely/timely.dart';
import 'package:focus/app/ui/elements/global_scaffold.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const GlobalScaffold(
      child: Timely(),
    );
  }
}
