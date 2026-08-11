@Timeout(Duration(minutes: 2))
library;

import 'dart:io';

import 'package:senalgo/core/interpreter/interpreter.dart';
import 'package:senalgo/core/lexer/lexer.dart';
import 'package:senalgo/core/parser/parser.dart';
import 'package:senalgo/core/transpiler/python_transpiler.dart';
import 'package:test/test.dart';

/// Exécute [source] avec l'interpréteur SenAlgo.
Future<String> _viaInterpreteur(String source) async {
  var sortie = '';
  final programme = Parser(Lexer(source).scanTokens()).parse();
  await Interpreter(onPrint: (m) => sortie += m, onRead: () async => '0').interpret(programme);
  return sortie;
}

/// Traduit [source] en Python et exécute le résultat.
Future<String> _viaPython(String source, Directory dossier) async {
  final programme = Parser(Lexer(source).scanTokens()).parse();
  final code = PythonTranspiler().transpile(programme);
  final fichier = File('${dossier.path}/programme.py')..writeAsStringSync(code);
  final r = await Process.run('python3', [fichier.path]);
  if (r.exitCode != 0) {
    fail('Le code Python généré a échoué :\n${r.stderr}\n--- code ---\n$code');
  }
  return r.stdout as String;
}

void main() {
  late Directory dossier;

  setUpAll(() {
    if (Process.runSync('python3', ['--version']).exitCode != 0) {
      throw StateError('python3 est requis pour ces tests');
    }
    dossier = Directory.systemTemp.createTempSync('senalgo_py');
  });

  tearDownAll(() => dossier.deleteSync(recursive: true));

  /// Vérifie que les deux exécutions donnent exactement le même résultat.
  Future<void> memeResultat(String titre, String source) async {
    final attendu = await _viaInterpreteur(source);
    final obtenu = await _viaPython(source, dossier);
    expect(obtenu, equals(attendu), reason: 'divergence sur « $titre »');
  }

  test('Un appel avec paramètre résultat imbriqué dans une expression', () async {
    // Régression : la traduction produisait « x = (3 + Calcul(5, t)) », or la
    // fonction Python renvoie un tuple. Le code levait une TypeError et « t »
    // n'était jamais mis à jour.
    await memeResultat('appel imbriqué', '''
ALGORITHME T
FONCTION Calcul(donnee a : entier, resultat trace : entier) : entier
DEBUT
  trace <- a
  RETOURNER a * 2
FIN

VARIABLES x, t : entier
DEBUT
  x <- 3 + Calcul(5, t)
  ecrire(x, " ", t)
FIN
''');
  });

  test('Deux appels imbriqués dans la même expression', () async {
    await memeResultat('deux appels', '''
ALGORITHME T
FONCTION F(donnee a : entier, resultat vu : entier) : entier
DEBUT
  vu <- a
  RETOURNER a + 1
FIN

VARIABLES x, p, q : entier
DEBUT
  x <- F(1, p) * F(10, q)
  ecrire(x, " ", p, " ", q)
FIN
''');
  });

  test("Appel avec paramètre résultat dans une condition de SI", () async {
    await memeResultat('condition SI', '''
ALGORITHME T
FONCTION Test(donnee a : entier, resultat vu : entier) : entier
DEBUT
  vu <- a
  RETOURNER a
FIN

VARIABLES v : entier
DEBUT
  SI Test(4, v) > 2 ALORS
    ecrire("grand ", v)
  SINON
    ecrire("petit ", v)
  FINSI
FIN
''');
  });

  test('Appel avec paramètre résultat dans une condition de TANT QUE', () async {
    // La condition doit être réévaluée à chaque tour : la remontée ne peut pas
    // se faire avant la boucle.
    await memeResultat('condition TANT QUE', '''
ALGORITHME T
FONCTION Suivant(donnee a : entier, resultat vu : entier) : entier
DEBUT
  vu <- a + 1
  RETOURNER a + 1
FIN

VARIABLES i, v : entier
DEBUT
  i <- 0
  TANTQUE Suivant(i, v) < 4 FAIRE
    i <- i + 1
  FINTANTQUE
  ecrire(i, " ", v)
FIN
''');
  });

  test('Procédure donnée-résultat appelée comme instruction', () async {
    await memeResultat('échange', '''
ALGORITHME T
PROCEDURE Echanger(donnee-resultat a : entier, donnee-resultat b : entier)
VARIABLES tmp : entier
DEBUT
  tmp <- a
  a <- b
  b <- tmp
FIN

VARIABLES x, y : entier
DEBUT
  x <- 1
  y <- 2
  Echanger(x, y)
  ecrire(x, " ", y)
FIN
''');
  });

  test('Programme sans paramètre de sortie : boucles, tableaux, conditions', () async {
    await memeResultat('programme complet', '''
ALGORITHME T
VARIABLES
  t : TABLEAU[1..5] DE entier
  i, s : entier
DEBUT
  POUR i ALLANT DE 1 à 5 FAIRE
    t[i] <- i * i
  FINPOUR
  s <- 0
  POUR i ALLANT DE 1 à 5 FAIRE
    s <- s + t[i]
  FINPOUR
  SI s > 50 ALORS
    ecrire("grand ", s)
  SINONSI s > 20 ALORS
    ecrire("moyen ", s)
  SINON
    ecrire("petit ", s)
  FINSI
FIN
''');
  });

  test('REPETER ... JUSQU\'A', () async {
    await memeResultat('repeter', '''
ALGORITHME T
VARIABLES n : entier
DEBUT
  n <- 0
  REPETER
    n <- n + 1
  JUSQUA n >= 4
  ecrire(n)
FIN
''');
  });

  group('DIV et MOD avec des opérandes négatifs', () {
    // Régression : DIV se traduisait par // et MOD par % de Python, qui
    // arrondissent vers moins l'infini et suivent le signe du diviseur. DIV
    // tronque vers zéro et MOD reste toujours positif (comme ~/ et % de
    // Dart, que suit l'interprète) : les deux ne coïncidaient que pour des
    // opérandes positifs, jamais exercés par les autres tests de ce fichier.

    test('DIV, dividende négatif', () async {
      await memeResultat('DIV dividende négatif', '''
ALGORITHME T
VARIABLES a : entier
DEBUT
  a <- (-7) DIV 2
  ecrire(a)
FIN
''');
    });

    test('DIV, diviseur négatif', () async {
      await memeResultat('DIV diviseur négatif', '''
ALGORITHME T
VARIABLES a : entier
DEBUT
  a <- 7 DIV (-2)
  ecrire(a)
FIN
''');
    });

    test('DIV, dividende et diviseur négatifs', () async {
      await memeResultat('DIV deux négatifs', '''
ALGORITHME T
VARIABLES a : entier
DEBUT
  a <- (-7) DIV (-2)
  ecrire(a)
FIN
''');
    });

    test('MOD, diviseur négatif', () async {
      await memeResultat('MOD diviseur négatif', '''
ALGORITHME T
VARIABLES a : entier
DEBUT
  a <- 7 MOD (-3)
  ecrire(a)
FIN
''');
    });

    test('MOD, dividende négatif', () async {
      await memeResultat('MOD dividende négatif', '''
ALGORITHME T
VARIABLES a : entier
DEBUT
  a <- (-7) MOD 3
  ecrire(a)
FIN
''');
    });

    test('MOD, dividende et diviseur négatifs', () async {
      await memeResultat('MOD deux négatifs', '''
ALGORITHME T
VARIABLES a : entier
DEBUT
  a <- (-7) MOD (-3)
  ecrire(a)
FIN
''');
    });

    test('DIV et MOD, opérandes positifs : non-régression', () async {
      await memeResultat('DIV/MOD positifs', '''
ALGORITHME T
VARIABLES a, b : entier
DEBUT
  a <- 17 DIV 5
  b <- 17 MOD 5
  ecrire(a, " ", b)
FIN
''');
    });
  });

  test('entier(x) : conversion d\'un réel, y compris négatif', () async {
    // Régression : 'entier' est le mot réservé du type ET le nom de cette
    // fonction intégrée ; 'entier(x)' ne passait pas l'analyse syntaxique,
    // donc ce chemin (parseur, analyse sémantique, interprète, transpileur)
    // n'avait jamais été exercé de bout en bout.
    await memeResultat('entier() sur un réel positif et un réel négatif', '''
ALGORITHME T
VARIABLES x, y : reel
VARIABLES a, b : entier
DEBUT
  x <- 3.9
  y <- -3.9
  a <- entier(x)
  b <- entier(y)
  ecrire(a, " ", b)
FIN
''');
  });
}
