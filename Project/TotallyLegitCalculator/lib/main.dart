import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'mobile_app/Calculator_mobile.dart';
import 'desktop_app/Calculator_desktop.dart';
import 'desktop_app/Settings_desktop.dart';
import 'desktop_app/Secret_desktop.dart';
import 'mobile_app/Secret_mobile.dart';
import 'dart:io' show Platform;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(400, 800),
    center: true,
    backgroundColor: Colors.transparent,
    //skipTaskbar: false,
    //titleBarStyle: TitleBarStyle.normal,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    Widget homeWidget;
    Map<String, WidgetBuilder> routes = {};

    if (Platform.isAndroid || Platform.isIOS) {
      homeWidget = const Calculatorscreen();
      routes = {'/secret_mobile': (context) => const SecretMobileApp()};
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      print("Spuštěno na desktopu. Zde bude desktopová verze kalkulačky.");
      homeWidget = const CalculatorScreenDesktop();
      routes = {
        '/secret_desktop': (context) => const TotallySecretApp(),
        '/settings': (context) => const SettingsScreen(),
      };
    } else {
      homeWidget = const Center(child: Text('Nepodporovaná platforma'));
    }

    return MaterialApp(
      title: 'Calculator',
      theme: ThemeData.dark(),
      home: homeWidget,
      routes: routes, // Používáme dynamicky definované trasy
    );
  }
}
