import 'package:cron/app/app.dart';
import 'package:cron/bootstrap.dart';
import 'package:cron/core/data/object_box.dart';
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
