import 'package:flutter/material.dart';
import 'package:focus/app/core/app/view/app.dart';
import 'package:focus/app/data/object_box.dart';
import 'package:focus/app/ui/elements/global_scaffold.dart';
import 'package:focus/bootstrap.dart';
import 'package:focus/mocked_design/mocked_home_screen.dart';
import 'package:go_router/go_router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  bootstrap(() async {
    final objectBox = await ObjectBox.create();
    return App(
      router: MockedDesignRouter().router,
      objectBox: objectBox,
    );
  });
}

class StorybookApp extends StatelessWidget {
  const StorybookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GlobalScaffold(child: Container());
  }
}

class MockedDesignRouter {
  GoRouter get router => GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const MockedHomeScreen(),
          ),
        ],
      );
}
