import 'package:senalgo/core/lexer/lexer.dart';
import 'package:senalgo/core/parser/parser.dart';
import 'package:senalgo/core/ast/ast.dart';
import 'package:test/test.dart';

void _attendErreurNonImplemente(String source) {
  expect(
    () => Parser(Lexer(source).scanTokens()).parse(),
    throwsA(predicate((e) => e.toString().contains("n'est pas encore implémenté"))),
  );
}

void main() {
  test('Parser builds AST for basic algorithm', () {
    const source = '''
ALGORITHME Somme
VAR a, b, s: entier
DEBUT
  a <- 5
  b <- 10
  s <- a + b
  ecrire(s)
FIN
''';
    final tokens = Lexer(source).scanTokens();
    final parser = Parser(tokens);
    final program = parser.parse();
    expect(program.name, equals("Somme"));
    expect(program.declarations.length, equals(1));
    expect(program.body.statements.length, equals(4));
  });

  test('Parser handles SI block', () {
    const source = '''
DEBUT
  SI x > 0 ALORS
    ecrire("Positif")
  SINONSI x < 0 ALORS
    ecrire("Negatif")
  SINON
    ecrire("Nul")
  FINSI
FIN
''';
    final tokens = Lexer(source).scanTokens();
    final program = Parser(tokens).parse();
    expect(program.body.statements[0], isA<IfNode>());
  });

  test('Parser handles correct loops', () {
    const source = '''
DEBUT
  TANTQUE vrai FAIRE
    ecrire("boucle")
  FINTANTQUE
  POUR i ALLANT DE 1 à 10 FAIRE
    ecrire(i)
  FINPOUR
FIN
''';
    final tokens = Lexer(source).scanTokens();
    final program = Parser(tokens).parse();
    expect(program.body.statements[0], isA<WhileNode>());
    expect(program.body.statements[1], isA<ForNode>());
  });

  group('Types personnalisés non implémentés', () {
    // Ces mots-clés étaient reconnus par l'analyseur lexical puis ignorés en
    // silence par le parseur : le programme s'exécutait « à moitié » sans le
    // moindre message. On exige désormais une erreur explicite.
    test('Structure au niveau du programme', () {
      _attendErreurNonImplemente('''
ALGORITHME AvecStructure
STRUCTURE Point
  x, y : entier
FIN
DEBUT
  ecrire("ok")
FIN
''');
    });

    test('Type au niveau du programme', () {
      _attendErreurNonImplemente('''
ALGORITHME AvecType
TYPE Couleur = (rouge, vert, bleu)
DEBUT
  ecrire("ok")
FIN
''');
    });

    test('Structure dans les déclarations locales d\'une procédure', () {
      _attendErreurNonImplemente('''
PROCEDURE P()
STRUCTURE Point
  x : entier
FIN
DEBUT
  ecrire("ok")
FIN

DEBUT
  P()
FIN
''');
    });
  });
}
