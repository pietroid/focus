import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:focus/app/for_you/bloc/for_you_cubit.dart';
import 'package:focus/app/for_you/bloc/for_you_tab_cubit.dart';
import 'package:focus/app/home_body/bloc/home_body_cubit.dart';
import 'package:focus/app/home_timely_section/bloc/timely_cubit.dart';
import 'package:things/things.dart';

class HomeBodyBuilder extends StatelessWidget {
  const HomeBodyBuilder({
    required this.builder,
    super.key,
  });
  final Widget Function(BuildContext context, List<HomeBodySection> data)
      builder;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ForYouTabCubit, Thing>(
      builder: (context, forYouTabState) {
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
                      selectedTab: forYouTabState,
                      mainThing: thing,
                      tabs: thing.children,
                      children: thing.children
                          .firstWhere((e) => e.id == forYouTabState.id)
                          .children,
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
      },
    );
  }
}
