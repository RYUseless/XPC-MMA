import 'Button_values.dart';
import 'package:flutter/material.dart';

class CalculatorBackend {
  final Function(VoidCallback) setStateCallback;
  final Function(String) onExpressionChanged;
  final Function(String) onResultChanged;
  final Function(bool) onOpenParenthesisChanged;
  final Function() calculateResult;

  CalculatorBackend({
    required this.setStateCallback,
    required this.onExpressionChanged,
    required this.onResultChanged,
    required this.onOpenParenthesisChanged,
    required this.calculateResult,
  });

  void onBtnTap(
    String value,
    String expression,
    String result,
    bool openParenthesis,
  ) {
    if (value == Btn.clr) {
      setStateCallback(() {
        onExpressionChanged("");
        onResultChanged("0");
        onOpenParenthesisChanged(false);
      });
      return;
    } else if (value == Btn.calculate) {
      calculateResult();
      return;
    } else if (value == Btn.zav) {
      setStateCallback(() {
        onExpressionChanged(expression + (openParenthesis ? ")" : "("));
        onOpenParenthesisChanged(!openParenthesis);
      });
      return;
    } else if (value == Btn.per) {
      if (expression.isNotEmpty) {
        // Zkontrolujeme, zda expression obsahuje operátory (+, -, ×, ÷)
        if (expression.contains('+') ||
            expression.contains('-') ||
            expression.contains('×') ||
            expression.contains('÷')) {
          if (result != "0" && result != "Error") {
            try {
              double number = double.parse(result);
              setStateCallback(() {
                onExpressionChanged("");
                onResultChanged((number / 100).toStringAsPrecision(3));
                if (result.endsWith(".0")) {
                  onResultChanged(result.substring(0, result.length - 2));
                }
              });
            } catch (e) {
              setStateCallback(() {
                onResultChanged("Error");
              });
            }
          }
        } else {
          // Pokud expression obsahuje pouze číslo
          try {
            double number = double.parse(expression);
            setStateCallback(() {
              onExpressionChanged("");
              onResultChanged((number / 100).toStringAsPrecision(3));
              if (result.endsWith(".0")) {
                onResultChanged(result.substring(0, result.length - 2));
              }
            });
          } catch (e) {
            setStateCallback(() {
              onResultChanged("Error");
            });
          }
        }
      } else {
        // Pokud je expression prázdný, použijeme result
        if (result != "0" && result != "Error") {
          try {
            double number = double.parse(result);
            setStateCallback(() {
              onExpressionChanged("");
              onResultChanged((number / 100).toStringAsPrecision(3));
              if (result.endsWith(".0")) {
                onResultChanged(result.substring(0, result.length - 2));
              }
            });
          } catch (e) {
            setStateCallback(() {
              onResultChanged("Error");
            });
          }
        }
      }
      return;
    } else if (value != Btn.del) {
      setStateCallback(() {
        onExpressionChanged(expression + value);
      });
    }
  }
}
