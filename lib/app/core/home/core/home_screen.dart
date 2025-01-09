import 'package:flutter/material.dart';
import 'package:focus/app/core/home/core/sections/timely/timely.dart';
import 'package:focus/app/ui/creation_bottom_sheet.dart';
import 'package:focus/app/ui/elements/global_scaffold.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final creationBottomSheet = context.read<CreationBottomSheet>();
    return GlobalScaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color.fromARGB(255, 0, 125, 187),
        onPressed: () {
          creationBottomSheet.show(context);
        },
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.black),
      ),
      child: const Timely(),
    );
  }
}
