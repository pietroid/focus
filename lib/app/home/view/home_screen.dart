import 'package:flutter/material.dart';
import 'package:focus/app/focus/view/global_scaffold.dart';
import 'package:focus/app/home/header/view/home_header.dart';
import 'package:focus/app/home/body/view/body.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const GlobalScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeHeader(),
          Expanded(child: HomeBody()),
        ],
      ),
    );
  }
}
