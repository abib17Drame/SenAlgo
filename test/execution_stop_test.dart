import 'package:flutter_test/flutter_test.dart';
import 'package:senalgo/core/lexer/lexer.dart';
import 'package:senalgo/core/parser/parser.dart';
import 'package:senalgo/core/interpreter/interpreter.dart';

/// Programme qui ne se termine jamais de lui-même.
const String boucleInfinie = '''
ALGORITHME Gel
VARIABLES
  i: entier
DEBUT
  i <- 0
  tant que i >= 0 faire
    i <- i + 1
  fintantque
FIN''';

Interpreter _interpreteur({void Function(String)? onPrint}) => Interpreter(
      onPrint: onPrint ?? (_) {},
      onRead: () async => "0",
    );

Future<void> _lancer(Interpreter interpreteur, String source) =>
    interpreteur.interpret(Parser(Lexer(source).scanTokens()).parse());

void main() {
  test("une boucle infinie s'arrête quand l'utilisateur le demande", () async {
    final interpreteur = _interpreteur();
    final execution = _lancer(interpreteur, boucleInfinie);

    // Laisse la boucle démarrer pour de bon, puis demande l'arrêt comme le
    // ferait le bouton « Arrêter ».
    await Future<void>.delayed(const Duration(milliseconds: 100));
    interpreteur.demanderArret();

    await expectLater(
      execution.timeout(const Duration(seconds: 5)),
      throwsA(kStoppedByUserSignal),
    );
  });

  test("l'interface garde la main pendant une boucle infinie", () async {
    final interpreteur = _interpreteur();
    final execution = _lancer(interpreteur, boucleInfinie);

    // Un Timer ne peut se déclencher que si la file d'événements est traitée.
    // S'il se déclenche pendant que la boucle tourne, c'est que l'interpréteur
    // rend bien la main — donc qu'un clic serait traité lui aussi.
    var interfaceServie = 0;
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      interfaceServie++;
    }

    expect(interfaceServie, 5, reason: "la boucle d'événements est affamée");

    interpreteur.demanderArret();
    await expectLater(execution, throwsA(kStoppedByUserSignal));
  });

  test("l'arrêt traverse les appels de fonction imbriqués", () async {
    const source = '''
ALGORITHME Recursif
VARIABLES
  n: entier
FONCTION Boucler(x: entier): entier
DEBUT
  tant que x >= 0 faire
    x <- x + 1
  fintantque
  Retourner x
FIN
DEBUT
  n <- Boucler(0)
FIN''';
    final interpreteur = _interpreteur();
    final execution = _lancer(interpreteur, source);

    await Future<void>.delayed(const Duration(milliseconds: 100));
    interpreteur.demanderArret();

    await expectLater(
      execution.timeout(const Duration(seconds: 5)),
      throwsA(kStoppedByUserSignal),
    );
  });

  test("un programme normal n'est pas perturbé par les points de contrôle", () async {
    final sortie = StringBuffer();
    const source = '''
ALGORITHME Somme
VARIABLES
  i, s: entier
DEBUT
  s <- 0
  pour i allant de 1 à 100 faire
    s <- s + i
  finpour
  ecrire(s)
FIN''';
    await _lancer(_interpreteur(onPrint: sortie.write), source);
    expect(sortie.toString(), "5050");
  });
}
