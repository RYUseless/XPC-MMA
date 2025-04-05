import 'package:flutter/material.dart';
import 'package:math_expressions/math_expressions.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:cover_app/common_utils/calcul.dart';
import 'package:cover_app/common_utils/Button_values.dart';

class Calculatorscreen extends StatefulWidget {
  const Calculatorscreen({super.key});

  @override
  State<Calculatorscreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<Calculatorscreen> {
  String expression = "";
  String result = "0";
  bool openParenthesis = false;
  Timer? _longPressTimer;
  bool _isLongPressing = false;
  late final CalculatorBackend _calculatorBackend; // PŘIDÁNA INSTANCE

  @override
  void initState() {
    super.initState();
    _calculatorBackend = CalculatorBackend(
      // PŘIDÁNA INICIALIZACE
      setStateCallback: setState,
      onExpressionChanged: (newExpression) {
        setState(() {
          expression = newExpression;
        });
      },
      onResultChanged: (newResult) {
        setState(() {
          result = newResult;
        });
      },
      onOpenParenthesisChanged: (newOpenParenthesis) {
        setState(() {
          openParenthesis = newOpenParenthesis;
        });
      },
      calculateResult: _calculateResult,
    );
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  // Funkce pro otevření URL
  _launchURL() async {
    final Uri url = Uri.parse('https://www.youtube.com/watch?v=dQw4w9WgXcQ');
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Horní část s výstupem – 40% výšky
            Expanded(
              flex: 3, // 40% z celkové výšky
              child: SingleChildScrollView(
                reverse: true,
                child: Container(
                  alignment: Alignment.bottomRight,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        expression.isEmpty ? "0" : expression,
                        style: const TextStyle(
                          fontSize: 30,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.end,
                      ),
                      Text(
                        result,
                        style: const TextStyle(
                          fontSize: 50,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.end,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Tlačítko "get help" s poloviční výškou oproti ostatním tlačítkům
            if (Btn.buttonValues.contains(Btn.help))
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: SizedBox(
                  //width: double.infinity,
                  height:
                      screenSize.width / 8, // Poloviční výška oproti ostatním
                  child: buildButton(Btn.help),
                ),
              ),

            // Spodní část (tlačítka) – 60% výšky
            Expanded(
              flex: 6, // 60% z celkové výšky
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final buttonWidth =
                      constraints.maxWidth / 4; // Šířka tlačítek
                  final buttonHeight =
                      constraints.maxHeight / 5; // Výška tlačítek

                  return Wrap(
                    spacing: 0, // Mezery mezi tlačítky
                    runSpacing: 0, // Mezery mezi řádky
                    alignment: WrapAlignment.start,
                    children:
                        Btn.buttonValues
                            .where((value) => value != Btn.help)
                            .map((value) {
                              return SizedBox(
                                width: buttonWidth,
                                height: buttonHeight,
                                child: buildButton(value),
                              );
                            })
                            .toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Builds a single calculator button with specified styling and tap handling.
  Widget buildButton(value) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Material(
        color: getBtnColor(value),
        clipBehavior: Clip.hardEdge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            MediaQuery.of(context).size.width * 0.015,
          ),
        ),
        child: InkWell(
          onTapDown: (details) {
            if (value == Btn.del && expression == "69") {
              _startLongPressTimer();
            }
          },
          onTapUp: (details) {
            _cancelLongPressTimer();
            if (value == Btn.del && expression != "SECRET") {
              _deleteLastCharacter();
            }
          },
          onTapCancel: () {
            _cancelLongPressTimer();
          },
          onTap:
              value == Btn.help
                  ? _launchURL
                  : () => _calculatorBackend.onBtnTap(
                    // ZMĚNA VOLÁNÍ
                    value,
                    expression,
                    result,
                    openParenthesis,
                  ),
          child: Center(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 25,
                color: value == Btn.help ? Colors.white : null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Determines the background color of the button based on its value.
  Color getBtnColor(value) {
    if ([Btn.del, Btn.clr].contains(value)) {
      return const Color.fromARGB(255, 248, 29, 0);
    } else if ([
      Btn.help,
      Btn.per,
      Btn.multiply,
      Btn.add,
      Btn.subtract,
      Btn.divide,
    ].contains(value)) {
      return const Color.fromARGB(255, 76, 76, 76);
    } else if ([Btn.calculate].contains(value)) {
      return const Color.fromARGB(255, 0, 92, 3);
    } else {
      return Colors.black87;
    }
  }

  void _startLongPressTimer() {
    _isLongPressing = true;
    _longPressTimer = Timer(const Duration(seconds: 3), () {
      if (_isLongPressing && expression == "69") {
        setState(() {
          expression = "---";
          result = "---";
        });
        Navigator.pushReplacementNamed(context, '/secret_mobile');
      }
      _isLongPressing = false;
    });
  }

  void _cancelLongPressTimer() {
    _isLongPressing = false;
    _longPressTimer?.cancel();
  }

  void _deleteLastCharacter() {
    if (expression.isNotEmpty) {
      setState(() {
        expression = expression.substring(0, expression.length - 1);
      });
    }
  }

  void _calculateResult() {
    if (expression.isEmpty) {
      return;
    }

    try {
      Parser p = Parser();
      Expression exp = p.parse(
        expression.replaceAll('×', '*').replaceAll('÷', '/'),
      );
      ContextModel cm = ContextModel();
      double eval = exp.evaluate(EvaluationType.REAL, cm);
      setState(() {
        result = _formatResult(eval);
      });
    } catch (e) {
      setState(() {
        result = "Error";
      });
    }
  }

  String _formatResult(double result) {
    if (result == result.toInt()) {
      return result.toInt().toString();
    } else {
      return result.toStringAsPrecision(3);
    }
  }
}
