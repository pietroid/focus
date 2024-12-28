import 'package:cron/app/core/app/app.dart';
import 'package:cron/app/data/object_box.dart';
import 'package:cron/bootstrap.dart';
import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  bootstrap(() async {
    final objectBox = await ObjectBox.create();
    return App(
      objectBox: objectBox,
    );
  });
}
