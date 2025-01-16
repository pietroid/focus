import 'package:flutter/material.dart';
import 'package:focus/app/core/app/app.dart';
import 'package:focus/app/core/initializer.dart';
import 'package:focus/app/data/object_box.dart';
import 'package:focus/app/ui/routing/app_router.dart';
import 'package:focus/bootstrap.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  bootstrap(() async {
    final objectBox = await ObjectBox.create();
    DataInitializer(box: objectBox).initialize();
    return App(
      objectBox: objectBox,
      router: AppRouter().router,
    );
  });
}
