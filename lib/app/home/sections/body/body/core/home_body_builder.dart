import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:focus/app/home/sections/body/for_you/core/for_you_cubit.dart';
import 'package:focus/app/home/sections/body/timely/core/timely_cubit.dart';
import 'package:focus/app/thing/data/thing.dart';

class HomeBodyBuilder extends StatelessWidget {
  const HomeBodyBuilder({
    required this.builder,
    super.key,
  });
  final Widget Function(BuildContext context, List<HomeBodySection> data)
      builder;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ForYouCubit, List<Thing>>(
      builder: (context, forYouState) {
        return BlocBuilder<TimelyCubit, List<Thing>>(
          builder: (contex, timelyState) {
            final renderedList = [
              ...timelyState.map(
                (thing) => HomeBodySection(
                  mainThing: thing,
                  children: thing.children,
                  type: HomeBodySectionType.regular,
                ),
              ),
              ...forYouState.map(
                (thing) => HomeBodySection(
                  mainThing: thing,
                  children: thing.children,
                  type: HomeBodySectionType.carousel,
                ),
              ),
            ];
            return builder(
              context,
              renderedList,
            );
          },
        );
      },
    );
  }
}

class HomeBodySection {
  HomeBodySection({
    required this.mainThing,
    required this.children,
    required this.type,
  });

  final Thing mainThing;
  final List<Thing> children;
  final HomeBodySectionType type;
}

enum HomeBodySectionType {
  regular,
  carousel,
}
