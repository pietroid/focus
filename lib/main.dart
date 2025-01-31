import 'package:flutter/material.dart';
import 'package:focus/app/app/app.dart';
import 'package:focus/app/thing/data/initializer.dart';
import 'package:focus/app/common_infrastructure/data/object_box.dart';
import 'package:focus/app/app/ui/app_router.dart';
import 'package:focus/bootstrap.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  bootstrap(() async {
    final objectBox = await ObjectBox.create();
    DataInitializer(box: objectBox).initialize();
    Intl.defaultLocale = 'pt_BR';
    await initializeDateFormatting('pt_BR');
    return App(
      objectBox: objectBox,
      router: AppRouter().router,
    );
  });
}
