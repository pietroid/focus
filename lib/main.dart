import 'package:flutter/material.dart';
import 'package:focus/app/app/view/app.dart';
import 'package:focus/app/app_router/app_router.dart';
import 'package:focus/bootstrap.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:local_service/local_service.dart';
import 'package:things/things.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  bootstrap(() async {
    final objectBox = await ObjectBox.create(
      openStore,
    );
    ThingsInitializer(box: objectBox).initialize();
    Intl.defaultLocale = 'pt_BR';
    await initializeDateFormatting('pt_BR');
    return App(
      objectBox: objectBox,
      router: AppRouter().router,
    );
  });
}
