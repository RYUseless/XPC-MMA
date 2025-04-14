import 'package:flutter/material.dart';
import 'package:math_expressions/math_expressions.dart';
import 'package:cover_app/common_utils/Button_values.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cover_app/common_utils/calcul.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

class CalculatorScreenDesktop extends ConsumerStatefulWidget {
  const CalculatorScreenDesktop({super.key});

  @override
  ConsumerState<CalculatorScreenDesktop> createState() =>
      _CalculatorScreenDesktopState();
}

class _CalculatorScreenDesktopState
    extends ConsumerState<CalculatorScreenDesktop>
    with WindowListener {
  String expression = "";
  String result = "0";
  bool openParenthesis = false;
  late final CalculatorBackend _calculatorBackend;

  Timer? _longPressTimer;
  bool _isLongPressing = false;
  final FocusNode _focusNode = FocusNode();

  bool isMaximized = false;

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
    windowManager.addListener(this);
    _checkIsMaximized();
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    _focusNode.dispose();
    windowManager.removeListener(this);
    super.dispose();
  }

  // Funkce pro otevření URL
  _launchURL() async {
    final Uri url = Uri.parse('https://www.youtube.com/watch?v=dQw4w9WgXcQ');
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }

  Future<void> _checkIsMaximized() async {
    bool isMax = await windowManager.isMaximized();
    setState(() {
      isMaximized = isMax;
    });
  }

  @override
  void onWindowMaximize() {
    _checkIsMaximized();
  }

  @override
  void onWindowUnmaximize() {
    _checkIsMaximized();
  }

  @override
  Future<void> onWindowResized() async {
    await _checkIsMaximized();
    setState(() {}); // Vyvolá rebuild widgetu pro přepočet velikostí
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        //color: Colors.grey[300], // barva pozadi
        child:
            isMaximized
                ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Levý obdélník s obrázkem
                    Container(
                      width: (screenSize.width - 400) / 2,
                      decoration: const BoxDecoration(
                        image: DecorationImage(
                          image: AssetImage(
                            "assets/images/reklama1.gif",
                          ), // Ujistěte se, že cesta je správná
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Container(
                      width: 400, // Šířka kalkulačky je 400px
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.black, // Barva ohraničení
                          width: 2, // Šířka ohraničení
                        ),
                      ),
                      child: _buildCalculator(context, 400, screenSize.height),
                    ),
                    // Pravý obdélník s obrázkem
                    Container(
                      width: (screenSize.width - 400) / 2,
                      decoration: const BoxDecoration(
                        image: DecorationImage(
                          image: AssetImage(
                            "assets/images/reklama2.png",
                          ), // Ujistěte se, že cesta je správná
                          fit: BoxFit.fill, //orig cover
                        ),
                      ),
                    ),
                  ],
                )
                : Center(
                  child: SizedBox(
                    width:
                        screenSize
                            .width, // Roztáhneme kalkulačku na celou obrazovku
                    child: _buildCalculator(
                      context,
                      screenSize.width,
                      screenSize.height,
                    ),
                  ),
                ),
      ),
    );
  }

  Widget _buildCalculator(
    BuildContext context,
    double constrainedWidth,
    double screenHeight,
  ) {
    final buttonCountPerRow = 4;

    return SizedBox(
      width: constrainedWidth,
      height: screenHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalHeight = constraints.maxHeight;
          final topHeight = totalHeight * 0.40;
          final bottomMaxHeight = totalHeight * 0.60;

          final numberOfRows =
              (Btn.buttonValues.length - 1) / buttonCountPerRow;
          final buttonHeight = bottomMaxHeight / numberOfRows - 1;
          final helpHeight = buttonHeight * 0.55;

          return Column(
            children: [
              SizedBox(
                height: topHeight,
                child: Padding(
                  padding: EdgeInsets.all(constrainedWidth * 0.04),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final outputFontSizeExpression =
                          constraints.maxHeight * 0.22;
                      final outputFontSizeResult = constraints.maxHeight * 0.3;

                      return Row(
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: SingleChildScrollView(
                                    // Přidáno pro expression
                                    scrollDirection: Axis.horizontal,
                                    child: Text(
                                      expression.isEmpty ? "0" : expression,
                                      style: TextStyle(
                                        fontSize: outputFontSizeExpression,
                                        color: Colors.grey,
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: SingleChildScrollView(
                                    // Přidáno pro result
                                    scrollDirection: Axis.horizontal,
                                    child: Text(
                                      result,
                                      style: TextStyle(
                                        fontSize: outputFontSizeResult,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
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
              const Spacer(),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: bottomMaxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    if (Btn.buttonValues.contains(Btn.help))
                      Padding(
                        padding: EdgeInsets.all(constrainedWidth * 0.004),
                        child: SizedBox(
                          width: double.infinity,
                          height: helpHeight,
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
                              (Btn.buttonValues.length - 1) / buttonCountPerRow;
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

  @override
  void onWindowClose() {
    // TODO: implement onWindowClose
  }

  @override
  void onWindowFocus() {
    // TODO: implement onWindowFocus
  }

  @override
  void onWindowMoved() {
    // TODO: implement onWindowMoved
  }

  @override
  void onWindowBlur() {
    // TODO: implement onWindowBlur
  }

  @override
  void onWindowDocked() {
    // TODO: implement onWindowDocked
  }

  @override
  void onWindowUndocked() {
    // TODO: implement onWindowUndocked
  }

  @override
  void onWindowMinimize() {
    // TODO: implement onWindowMinimize
  }

  @override
  void onWindowRestored() {
    // TODO: implement onWindowRestored
  }
}
