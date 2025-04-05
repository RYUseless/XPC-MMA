import 'package:flutter/material.dart';
import 'Calculator_mobile.dart'; // Importuj mobilní kalkulačku

class SecretMobileApp extends StatelessWidget {
  const SecretMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //appBar: AppBar(title: const Text('Super duper secret chatting App')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'Na to se napiju bru',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Image.asset(
              'assets/images/samko.jpg', // Cesta k tvé fotce
              fit: BoxFit.cover, // Jak se má obrázek přizpůsobit rozměrům
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const Calculatorscreen(),
                  ),
                );
              },
              child: const Text('Go back to coverApp'),
            ),
          ],
        ),
      ),
    );
  }
}
