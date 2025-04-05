import 'package:flutter/material.dart';
import 'Calculator_desktop.dart'; // Importujte desktopovou kalkulačku (upravte cestu, pokud je potřeba)

class TotallySecretApp extends StatelessWidget {
  const TotallySecretApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //appBar: AppBar(title: const Text('Super duper secret chatting App')),
      body: Stack(
        // Používáme Stack pro vrstvení widgetů
        children: <Widget>[
          // Obrázek jako pozadí s průhledností
          Opacity(
            opacity:
                0.3, // Nastavte požadovanou úroveň průhlednosti (0.0 = zcela průhledné, 1.0 = zcela neprůhledné)
            child: SizedBox.expand(
              // SizedBox.expand zajistí, že obrázek pokryje celou obrazovku
              child: Image.asset(
                'assets/images/samko.jpg', // Cesta k vaší fotce
                fit:
                    BoxFit
                        .cover, // Zajistí, že obrázek pokryje celou plochu, může oříznout
              ),
            ),
          ),
          // Obsah na popředí
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Text(
                  'Na to se napiju bru',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                // Již nepotřebujeme Image.asset zde, je na pozadí
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CalculatorScreenDesktop(),
                      ),
                    );
                  },
                  child: const Text('Go back to coverApp'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
