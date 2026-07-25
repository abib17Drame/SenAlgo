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
}
