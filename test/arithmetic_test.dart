import 'package:flutter_test/flutter_test.dart';
import 'package:senalgo/core/lexer/lexer.dart';
import 'package:senalgo/core/parser/parser.dart';
import 'package:senalgo/core/interpreter/interpreter.dart';
import 'package:senalgo/core/transpiler/python_transpiler.dart';

/// Exécute un programme réduit à un `ecrire` et renvoie ce qui a été affiché.
Future<String> _afficher(String expression, {String declarations = ''}) async {
  final sortie = StringBuffer();
  final source = '''
ALGORITHME T
$declarations
DEBUT
  ecrire($expression)
FIN''';
  final programme = Parser(Lexer(source).scanTokens()).parse();
  await Interpreter(onPrint: sortie.write, onRead: () async => "0").interpret(programme);
  return sortie.toString();
}

void main() {
  group('division par zéro', () {
    test('la division réelle lève une erreur au lieu de renvoyer Infinity', () {
      expect(_afficher('5 / 0'), throwsA(contains('Division par zéro')));
    });

    test('la division entière lève une erreur', () {
      expect(_afficher('5 div 0'), throwsA(contains('Division entière par zéro')));
    });

    test('le modulo lève une erreur en français, pas une exception Dart', () {
      expect(
        _afficher('5 mod 0'),
        throwsA(allOf(
          contains('Modulo par zéro'),
          isNot(contains('IntegerDivisionByZero')),
        )),
      );
    });

    test("le message indique la ligne fautive", () {
      expect(_afficher('5 / 0'), throwsA(contains('ligne 4')));
    });

    test('une division valide fonctionne toujours', () async {
      expect(await _afficher('7 / 2'), '3.5');
      expect(await _afficher('7 div 2'), '3');
      expect(await _afficher('7 mod 2'), '1');
    });
  });

  group('opérateur puissance', () {
    test('deux entiers donnent un entier', () async {
      expect(await _afficher('2 ^ 3'), '8');
    });

    test('la notation ** est acceptée aussi', () async {
      expect(await _afficher('2 ** 3'), '8');
    });

    test('une seule étoile reste la multiplication', () async {
      expect(await _afficher('2 * 3'), '6');
    });

    test('un réel quelque part donne un réel', () async {
      expect(await _afficher('2.0 ^ 3'), '8.0');
    });

    test('un exposant négatif donne un réel', () async {
      expect(await _afficher('2 ^ -2'), '0.25');
    });

    test('la puissance est prioritaire sur la multiplication', () async {
      expect(await _afficher('2 * 3 ^ 2'), '18');
    });

    test('la puissance est prioritaire sur le moins unaire : -2^2 vaut -4', () async {
      expect(await _afficher('-2 ^ 2'), '-4');
    });

    test('la puissance est associative à droite : 2^3^2 vaut 512', () async {
      expect(await _afficher('2 ^ 3 ^ 2'), '512');
    });

    test('les parenthèses restent prioritaires', () async {
      expect(await _afficher('(2 ^ 3) ^ 2'), '64');
    });

    test('la puissance se traduit en ** en Python', () {
      const source = '''
ALGORITHME P
VARIABLES
  x: entier
DEBUT
  x <- 2 ^ 10
FIN''';
      final python = PythonTranspiler().transpile(Parser(Lexer(source).scanTokens()).parse());
      expect(python, contains('(2 ** 10)'));
    });
  });
}
