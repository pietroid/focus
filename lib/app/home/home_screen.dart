import 'package:flutter/material.dart';
import 'package:focus/app/home/sections/header/core/home_header.dart';
import 'package:focus/app/home/sections/body/body/core/body.dart';
import 'package:focus/app/common_infrastructure/ui/global_scaffold.dart';

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
