import 'package:flutter/material.dart';
import 'package:math_expressions/math_expressions.dart';
import 'dart:async';
import 'package:cover_app/common_utils/Button_values.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cover_app/common_utils/calcul.dart';

class CalculatorScreenDesktop extends StatefulWidget {
  const CalculatorScreenDesktop({super.key});

  @override
  State<CalculatorScreenDesktop> createState() =>
      _CalculatorScreenDesktopState();
}

class _CalculatorScreenDesktopState extends State<CalculatorScreenDesktop> {
  String expression = "";
  String result = "0";
  bool openParenthesis = false;
  late final CalculatorBackend _calculatorBackend;

  Timer? _longPressTimer;
  bool _isLongPressing = false;
  FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
    _calculatorBackend = CalculatorBackend(
      setStateCallback: setState,
      onExpressionChanged: (newExpression) => expression = newExpression,
      onResultChanged: (newResult) => result = newResult,
      onOpenParenthesisChanged:
          (newOpenParenthesis) => openParenthesis = newOpenParenthesis,
      calculateResult: _calculateResult,
    );
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    _focusNode.dispose();
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
    final buttonCountPerRow = 4;

    return Focus(
      focusNode: _focusNode,
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final totalHeight = constraints.maxHeight;
              final topHeight = totalHeight * 0.40;
              final bottomMaxHeight = totalHeight * 0.60;

              // Výpočet pro tlačítka
              final numberOfRows =
                  (Btn.buttonValues.length - 1) / buttonCountPerRow;
              final buttonHeight = bottomMaxHeight / numberOfRows - 1;

              // Výpočet pro "get help" tlačítko (55% výšky oproti ostatním)
              final helpHeight = buttonHeight * 0.55;

              return Column(
                children: [
                  // Horní výstupní část – 30 %
                  SizedBox(
                    height: topHeight,
                    child: Padding(
                      padding: EdgeInsets.all(screenSize.width * 0.04),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final outputFontSizeExpression =
                              constraints.maxHeight * 0.22;
                          final outputFontSizeResult =
                              constraints.maxHeight * 0.3;

                          return Row(
                            children: [
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        expression.isEmpty ? "0" : expression,
                                        style: TextStyle(
                                          fontSize: outputFontSizeExpression,
                                          color: Colors.grey,
                                        ),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        result,
                                        style: TextStyle(
                                          fontSize: outputFontSizeResult,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),

                  // Mezera mezi výstupem a tlačítky
                  const Spacer(),

                  // Tlačítka – max 55 % výšky
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: bottomMaxHeight),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        if (Btn.buttonValues.contains(Btn.help))
                          Padding(
                            padding: EdgeInsets.all(screenSize.width * 0.004),
                            child: SizedBox(
                              width: double.infinity,
                              height: helpHeight, // výška tlačítka "get help"
                              child: buildButton(
                                Btn.help,
                                helpHeight * 0.4,
                                context,
                              ),
                            ),
                          ),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final buttonWidth =
                                  constraints.maxWidth / buttonCountPerRow;
                              final availableHeightForButtons =
                                  constraints.maxHeight;
                              final numberOfRows =
                                  (Btn.buttonValues.length - 1) /
                                  buttonCountPerRow;
                              final buttonHeight =
                                  availableHeightForButtons / numberOfRows - 1;
                              final fontSize = buttonHeight * 0.4;

                              return Wrap(
                                alignment: WrapAlignment.start,
                                runAlignment: WrapAlignment.start,
                                spacing: 0,
                                runSpacing: 0,
                                children:
                                    Btn.buttonValues
                                        .where((value) => value != Btn.help)
                                        .map((value) {
                                          return SizedBox(
                                            width: buttonWidth,
                                            height: buttonHeight,
                                            child: buildButton(
                                              value,
                                              fontSize,
                                              context,
                                            ),
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
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget buildButton(value, double fontSize, BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.005),
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
              _startLongPressTimer(context);
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
                fontSize: fontSize,
                color: value == Btn.help ? Colors.white : null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color getBtnColor(value) {
    if ([Btn.del, Btn.clr].contains(value)) {
      return const Color.fromARGB(255, 248, 29, 0);
    } else if ([
      Btn.per,
      Btn.multiply,
      Btn.add,
      Btn.subtract,
      Btn.divide,
    ].contains(value)) {
      return const Color.fromARGB(255, 76, 76, 76);
    } else if ([Btn.calculate].contains(value)) {
      return const Color.fromARGB(255, 0, 92, 3);
    } else if ([Btn.help].contains(value)) {
      return const Color.fromARGB(255, 76, 76, 76); // Barva pro "get help"
    } else {
      return Colors.black87;
    }
  }

  void _startLongPressTimer(BuildContext context) {
    _isLongPressing = true;
    _longPressTimer = Timer(const Duration(seconds: 3), () {
      if (_isLongPressing && expression == "69") {
        setState(() {
          expression = "---";
          result = "---";
        });
        Navigator.pushReplacementNamed(
          context,
          '/secret_desktop', // Navigujeme na desktopovou trasu
        );
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
      print("Error evaluating expression: $e");
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
