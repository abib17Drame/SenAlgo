import 'package:senalgo/core/interpreter/interpreter.dart';
import 'package:senalgo/core/lexer/lexer.dart';
import 'package:senalgo/core/parser/parser.dart';
import 'package:test/test.dart';

Future<String> _executer(String corps) async {
  var sortie = '';
  final source = 'ALGORITHME T\nVARIABLES a, b, c : entier\nDEBUT\n'
      '  a <- 1\n  b <- 2\n  c <- 3\n$corps\nFIN';
  final programme = Parser(Lexer(source).scanTokens()).parse();
  await Interpreter(onPrint: (m) => sortie += m, onRead: () async => '0').interpret(programme);
  return sortie;
}

void main() {
  group('Une expression peut être coupée sur plusieurs lignes', () {
    test("coupure après l'opérateur", () async {
      expect(await _executer('  ecrire(a +\n b)'), equals('3'));
    });

    test("coupure avant l'opérateur, dans un appel", () async {
      expect(await _executer('  ecrire(a\n + b)'), equals('3'));
    });

    test('entre parenthèses, opérateur en fin de ligne', () async {
      expect(await _executer('  ecrire((a +\n b) * c)'), equals('9'));
    });

    test('entre parenthèses, opérateur en début de ligne', () async {
      expect(await _executer('  ecrire((a\n + b) * c)'), equals('9'));
    });

    test('condition SI, opérateur en fin de ligne', () async {
      expect(await _executer('  SI a > 0 ET\n b > 0 ALORS\n ecrire("ok")\n FINSI'), equals('ok'));
    });

    test('condition SI, opérateur en début de ligne', () async {
      expect(await _executer('  SI a > 0\n ET b > 0 ALORS\n ecrire("ok")\n FINSI'), equals('ok'));
    });

    test('condition TANT QUE sur deux lignes', () async {
      expect(
        await _executer('  TANTQUE a < 3\n ET b > 0 FAIRE\n a <- a + 1\n FINTANTQUE\n ecrire(a)'),
        equals('3'),
      );
    });

    test("bornes d'un POUR sur deux lignes", () async {
      expect(await _executer('  POUR a ALLANT DE 1 à\n 3 FAIRE\n ecrire(a)\n FINPOUR'), equals('123'));
    });

    test('arguments répartis sur plusieurs lignes', () async {
      expect(await _executer('  ecrire(a,\n b,\n c)'), equals('123'));
    });
  });

  group('Le retour à la ligne délimite toujours les instructions', () {
    // Hors de tout groupement, un opérateur en début de ligne doit rester le
    // début d'une nouvelle instruction : sans quoi « x <- 1 » suivi de
    // « -2 » deviendrait une soustraction au lieu de deux instructions.
    test('deux affectations successives restent distinctes', () async {
      expect(await _executer('  a <- 1\n  b <- 2\n  ecrire(a, " ", b)'), equals('1 2'));
    });

    test("une valeur négative en début de ligne n'est pas absorbée", () async {
      expect(await _executer('  a <- 5\n  b <- 0 - 2\n  ecrire(a, " ", b)'), equals('5 -2'));
    });
  });
}
