import 'package:senalgo/core/lexer/lexer.dart';
import 'package:senalgo/core/parser/parser.dart';
import 'package:senalgo/core/interpreter/interpreter.dart';
import 'package:test/test.dart';

void main() {
  test('Interpreter executes basic algorithm', () async {
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
    String output = "";
    final tokens = Lexer(source).scanTokens();
    final program = Parser(tokens).parse();
    final interpreter = Interpreter(onPrint: (msg) => output += msg, onRead: () async => "0");
    await interpreter.interpret(program);
    expect(output, equals("15"));
  });

  test('Interpreter handles SI and loops', () async {
    const source = '''
VAR i: entier
DEBUT
  POUR i ALLANT DE 1 à 3 FAIRE
    SI i = 2 ALORS
      ecrire("Deux")
    SINON
      ecrire(i)
    FINSI
  FINPOUR
FIN
''';
    String output = "";
    final tokens = Lexer(source).scanTokens();
    final program = Parser(tokens).parse();
    final interpreter = Interpreter(onPrint: (msg) => output += msg, onRead: () async => "");
    await interpreter.interpret(program);
    expect(output, equals("1Deux3"));
  });

  test('Interpreter handles functions and procedures', () async {
    const source = '''
FONCTION carre(n: entier): entier
DEBUT
  RETOURNER n * n
FIN

PROCEDURE affiche_double(x: entier)
DEBUT
  ecrire(x * 2)
FIN

DEBUT
  ecrire(carre(5))
  affiche_double(10)
FIN
''';
    String output = "";
    final tokens = Lexer(source).scanTokens();
    final program = Parser(tokens).parse();
    final interpreter = Interpreter(onPrint: (msg) => output += msg, onRead: () async => "");

    await interpreter.interpret(program);
    expect(output, equals("2520"));
  });

  test('Selon avec gardes comparatives chaînées par et/ou', () async {
    const source = '''
ALGORITHME TauxSelonMontant
VARIABLES
  montant, taux : entier
DEBUT
  Lire montant
  Selon montant Faire
    < 1000 : taux <- 10
    ≥ 1000 et < 3000 : taux <- 20
    ≥ 3000 et < 10000 : taux <- 30
    ≥ 10000 : taux <- 40
  FinSelon
  Afficher taux
FIN
''';
    Future<String> tauxPour(String saisie) async {
      String output = "";
      final program = Parser(Lexer(source).scanTokens()).parse();
      final interpreter = Interpreter(onPrint: (m) => output += m, onRead: () async => saisie);
      await interpreter.interpret(program);
      return output;
    }

    expect(await tauxPour("500"), equals("10"));
    expect(await tauxPour("1500"), equals("20"));
    expect(await tauxPour("5000"), equals("30"));
    expect(await tauxPour("20000"), equals("40"));
  });

  test("Une erreur d'exécution est propagée à l'appelant", () async {
    // Régression : interpret() avalait autrefois toutes les erreurs, si bien
    // que l'interface affichait « Terminé » sur un programme qui avait planté.
    const source = '''
ALGORITHME Boum
DEBUT
  x <- 1
FIN
''';
    final program = Parser(Lexer(source).scanTokens()).parse();
    final interpreter = Interpreter(onPrint: (_) {}, onRead: () async => "");
    await expectLater(
      interpreter.interpret(program),
      throwsA(predicate((e) => e.toString().contains("Variable indéfinie"))),
    );
  });

  test("Le signal d'arrêt du pas-à-pas remonte intact", () async {
    const source = '''
ALGORITHME PasAPas
VARIABLES a : entier
DEBUT
  a <- 1
  a <- 2
FIN
''';
    final program = Parser(Lexer(source).scanTokens()).parse();
    final interpreter = Interpreter(
      onPrint: (_) {},
      onRead: () async => "",
      onStatement: (_, _) async => throw "__SENALGO_STOPPED_BY_USER__",
    );
    await expectLater(
      interpreter.interpret(program),
      throwsA(predicate((e) => e.toString().contains("__SENALGO_STOPPED_BY_USER__"))),
    );
  });

  test('Retourner au niveau du programme principal termine normalement', () async {
    const source = '''
ALGORITHME FinAnticipee
DEBUT
  ecrire("avant")
  RETOURNER
  ecrire("après")
FIN
''';
    String output = "";
    final program = Parser(Lexer(source).scanTokens()).parse();
    final interpreter = Interpreter(onPrint: (m) => output += m, onRead: () async => "");
    await interpreter.interpret(program);
    expect(output, equals("avant"));
  });
}
