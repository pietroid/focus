import 'package:flutter/material.dart';
import 'package:focus/app/core/app/app.dart';
import 'package:focus/app/data/object_box.dart';
import 'package:focus/bootstrap.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  bootstrap(() async {
    final objectBox = await ObjectBox.create();
    return App(
      objectBox: objectBox,
    );
  });
}
