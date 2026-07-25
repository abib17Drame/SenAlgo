import 'package:senalgo/core/lexer/lexer.dart';
import 'package:senalgo/core/parser/parser.dart';
import 'package:test/test.dart';

String _erreurPour(String source) {
  try {
    Parser(Lexer(source).scanTokens()).parse();
    return '';
  } catch (e) {
    return e.toString();
  }
}

void main() {
  group('Un mot réservé utilisé comme nom donne un message explicite', () {
    // Avant, tous ces cas produisaient « Nom de … attendu », qui n'indiquait
    // ni la cause ni la solution.
    test("nom d'algorithme", () {
      final erreur = _erreurPour('ALGORITHME Fin\nDEBUT\nFIN');
      expect(erreur, contains('mot réservé'));
      expect(erreur, contains("nom d'algorithme"));
      expect(erreur, contains('Fin'));
    });

    test('nom de variable', () {
      final erreur = _erreurPour('ALGORITHME T\nVARIABLES\n  Pas : entier\nDEBUT\nFIN');
      expect(erreur, contains('mot réservé'));
      expect(erreur, contains('nom de variable'));
    });

    test('nom de fonction', () {
      final erreur = _erreurPour('FONCTION Chaine(n : entier) : entier\nDEBUT\n RETOURNER n\nFIN\n\nDEBUT\nFIN');
      expect(erreur, contains('mot réservé'));
      expect(erreur, contains('nom de fonction'));
    });

    test('nom de paramètre', () {
      final erreur = _erreurPour('PROCEDURE P(Pour : entier)\nDEBUT\nFIN\n\nDEBUT\nFIN');
      expect(erreur, contains('mot réservé'));
      expect(erreur, contains('nom de paramètre'));
    });

    test("le message propose une solution", () {
      expect(_erreurPour('ALGORITHME Fin\nDEBUT\nFIN'), contains('Choisis un autre nom'));
    });

    test('la ligne est indiquée', () {
      expect(_erreurPour('ALGORITHME T\nVARIABLES\n  Selon : entier\nDEBUT\nFIN'), contains('ligne 3'));
    });
  });

  group('isReservedWord', () {
    test('reconnaît les mots-clés quelle que soit la casse', () {
      expect(Lexer.isReservedWord('FIN'), isTrue);
      expect(Lexer.isReservedWord('fin'), isTrue);
      expect(Lexer.isReservedWord('Pour'), isTrue);
      expect(Lexer.isReservedWord('tantque'), isTrue);
    });

    test('reconnaît les variantes accentuées et au pluriel', () {
      expect(Lexer.isReservedWord('réel'), isTrue);
      expect(Lexer.isReservedWord('variables'), isTrue);
      expect(Lexer.isReservedWord('début'), isTrue);
    });

    test('laisse passer un nom ordinaire', () {
      expect(Lexer.isReservedWord('compteur'), isFalse);
      expect(Lexer.isReservedWord('MonAlgo'), isFalse);
      expect(Lexer.isReservedWord('x'), isFalse);
    });
  });

  test('Un nom ordinaire reste accepté', () {
    expect(_erreurPour('ALGORITHME MonAlgo\nVARIABLES\n  compteur : entier\nDEBUT\nFIN'), isEmpty);
  });
}
