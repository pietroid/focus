import 'package:flutter/material.dart';
import 'package:focus/app/home_header/clock/view/clock.dart';
import 'package:focus/app/home_header/progress_bar/view/progress_bar.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Clock(),
          SizedBox(height: 15),
          ProgressBar(),
        ],
      ),
    );
  }
}
