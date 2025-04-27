import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io' show Platform;

// Podmíněný import window_manager (pouze pro desktop)
import 'package:window_manager/window_manager.dart'
    if (dart.library.html) 'package:flutter/material.dart'
    as wm;

// Mobile imports
import 'mobile_app/Calculator_mobile.dart';
import 'mobile_app/Settings_mobile.dart';
import 'mobile_app/Secret_mobile.dart';

// Desktop imports
import 'desktop_app/Calculator_desktop.dart';
import 'desktop_app/Settings_desktop.dart';
import 'desktop_app/Secret_desktop.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializace window_manager pouze na desktopu
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await wm.windowManager.ensureInitialized();

    wm.WindowOptions windowOptions = const wm.WindowOptions(
      size: Size(400, 800),
      center: true,
      backgroundColor: Colors.transparent,
    );

    wm.windowManager.waitUntilReadyToShow(windowOptions, () async {
      await wm.windowManager.show();
      await wm.windowManager.focus();
    });
  }

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
      routes = {
        '/secret_mobile': (context) => const TotallySecretMobileApp(),
        '/settings_mobile': (context) => const SettingsScreenMobile(),
      };
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
      routes: routes,
    );
  }
}
