package com.example.mma_cviko1;

import android.os.Bundle;
import android.widget.Button;
import android.widget.EditText;
import androidx.appcompat.app.AppCompatActivity;
import org.mariuszgromada.math.mxparser.Expression;

public class MainActivity extends AppCompatActivity {

    private EditText operationInput, resultOutput;
    private String currentInput = ""; // Uchovává aktuální vstup pro operace

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        operationInput = findViewById(R.id.operationInput);
        resultOutput = findViewById(R.id.resultOutput);

        // Přiřazení tlačítek a jejich posluchačů
        Button equalsButton = findViewById(R.id.equals);
        Button clearButton = findViewById(R.id.clearButton);
        Button backspaceButton = findViewById(R.id.backspaceButton);

        Button oneButton = findViewById(R.id.one);
        Button twoButton = findViewById(R.id.two);
        Button threeButton = findViewById(R.id.three);
        Button fourButton = findViewById(R.id.four);
        Button fiveButton = findViewById(R.id.five);
        Button sixButton = findViewById(R.id.six);
        Button sevenButton = findViewById(R.id.seven);
        Button eightButton = findViewById(R.id.eight);
        Button nineButton = findViewById(R.id.nine);
        Button zeroButton = findViewById(R.id.zero);

        Button plusButton = findViewById(R.id.plus);
        Button minusButton = findViewById(R.id.minus);
        Button multiplyButton = findViewById(R.id.multiplz);
        Button divideButton = findViewById(R.id.divideButton);

        Button dotButton = findViewById(R.id.dot);
        Button openBracketButton = findViewById(R.id.zavorka);
        Button closeBracketButton = findViewById(R.id.zavorka_zpet);

        // Nastavení akcí pro tlačítka
        if (equalsButton != null) {
            equalsButton.setOnClickListener(v -> {
                String expression = operationInput.getText().toString();
                String result = evaluateExpression(expression);
                resultOutput.setText(result);
            });
        }

        if (clearButton != null) {
            clearButton.setOnClickListener(v -> {
                currentInput = "";
                operationInput.setText("");
                resultOutput.setText("0");
            });
        }

        if (backspaceButton != null){
        backspaceButton.setOnClickListener(v -> {
            if (!currentInput.isEmpty()) {
                currentInput = currentInput.substring(0, currentInput.length() - 1);
                operationInput.setText(currentInput);
            }
        });
        }

        // Nastavení akcí pro číslice
        oneButton.setOnClickListener(v -> appendToInput("1"));
        twoButton.setOnClickListener(v -> appendToInput("2"));
        threeButton.setOnClickListener(v -> appendToInput("3"));
        fourButton.setOnClickListener(v -> appendToInput("4"));
        fiveButton.setOnClickListener(v -> appendToInput("5"));
        sixButton.setOnClickListener(v -> appendToInput("6"));
        sevenButton.setOnClickListener(v -> appendToInput("7"));
        eightButton.setOnClickListener(v -> appendToInput("8"));
        nineButton.setOnClickListener(v -> appendToInput("9"));
        zeroButton.setOnClickListener(v -> appendToInput("0"));

        // Nastavení akcí pro operátory
        plusButton.setOnClickListener(v -> appendToInput("+"));
        minusButton.setOnClickListener(v -> appendToInput("-"));
        multiplyButton.setOnClickListener(v -> appendToInput("*"));
        divideButton.setOnClickListener(v -> appendToInput("/"));

        // Nastavení akcí pro speciální znaky
        dotButton.setOnClickListener(v -> appendToInput("."));
        openBracketButton.setOnClickListener(v -> appendToInput("("));
        closeBracketButton.setOnClickListener(v -> appendToInput(")"));
    }

    // Funkce pro přidání textu do vstupu
    private void appendToInput(String value) {
        currentInput += value;
        operationInput.setText(currentInput);
    }

    // Funkce pro vyhodnocení matematického výrazu
    private String evaluateExpression(String expression) {
        // Použití knihovny mxParser pro výpočet výrazu
        Expression exp = new Expression(expression);

        // Vyhodnocení výrazu a získání výsledku
        double result = exp.calculate();

        if (Double.isNaN(result)) {
            return "Error"; // Pokud je výsledek nevalidní, zobrazí se chyba
        } else {
            return String.valueOf(result); // Jinak vrátíme výsledek jako text
        }
    }
}
