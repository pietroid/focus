import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:focus/app/home_header/bloc/clock_cubit.dart';
import 'package:focus/app/home_header/widgets/clock.dart';
import 'package:app_ui/src/string_formatter.dart';
import 'package:focus/app/home_header/widgets/progress_bar.dart';
import 'package:intl/intl.dart';

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
