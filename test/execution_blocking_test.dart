import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senalgo/state/execution_provider.dart';

/// Résultat d'un lancement : ce que la console a reçu et où l'exécution en
/// est arrivée.
class _Lancement {
  final String console;
  final ExecutionStatus statut;
  const _Lancement(this.console, this.statut);
}

/// Lance [source] à travers le vrai [Runner], comme le ferait le bouton
/// « Exécuter ».
///
/// Passe par un widget parce que `Runner` réclame un `WidgetRef` ; l'éditeur
/// n'est pas monté pour autant, seul le chemin d'exécution est exercé.
Future<_Lancement> _lancer(WidgetTester tester, String source) async {
  late WidgetRef capture;
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(
      home: Consumer(builder: (context, ref, _) {
        capture = ref;
        return const SizedBox.shrink();
      }),
    ),
  ));

  await Runner(capture).run(source);
  await tester.pump();

  return _Lancement(
    capture.read(consoleProvider).lines.join('\n'),
    capture.read(executionProvider).status,
  );
}

const _entete = 'ALGORITHME T\nVARIABLES\n  n : entier\nDEBUT\n';

void main() {
  testWidgets('un programme correct va au bout', (tester) async {
    final r = await _lancer(tester, '$_entete  n <- 21\n  ecrire(n * 2)\nFIN');
    expect(r.statut, ExecutionStatus.finished);
    expect(r.console, contains('42'));
  });

  testWidgets("une erreur sémantique empêche le programme de démarrer", (tester) async {
    // L'affichage précède volontairement la faute. Si le refus ne fonctionnait
    // pas, le programme tournerait jusqu'à l'affectation fautive : « j'ai
    // tourné » apparaîtrait, puis une erreur d'exécution. C'est ce qui
    // distingue un vrai refus d'un simple échec plus loin.
    final r = await _lancer(tester, '$_entete  ecrire("j\'ai tourné")\n  n <- "texte"\nFIN');

    expect(r.statut, ExecutionStatus.error);
    expect(r.console, contains('Exécution refusée'));
    expect(r.console, contains('1 erreur'));
    expect(r.console, isNot(contains("j'ai tourné")));
  });

  testWidgets('plusieurs erreurs sont toutes listées avant le refus', (tester) async {
    final r = await _lancer(tester, '$_entete  n <- "texte"\n  si n alors ecrire("x") finsi\nFIN');
    expect(r.console, contains('2 erreurs'));
    expect(r.console, contains('est un entier'));
    expect(r.console, contains('vraie ou fausse'));
  });

  testWidgets('un avertissement laisse le programme tourner', (tester) async {
    // Affecter un réel à un entier tronque : on prévient, on n'empêche pas.
    final r = await _lancer(tester, '$_entete  n <- 7.9\n  ecrire(n)\nFIN');

    expect(r.statut, ExecutionStatus.finished);
    expect(r.console, contains('partie décimale'));
    expect(r.console, isNot(contains('Exécution refusée')));
    expect(r.console, contains('7'));
  });

  testWidgets("une erreur d'exécution reste distincte d'un refus", (tester) async {
    // Rien n'est détectable à l'analyse ici : la division par zéro n'apparaît
    // qu'au moment de l'exécution.
    final r = await _lancer(tester, '$_entete  n <- 0\n  ecrire(10 div n)\nFIN');
    expect(r.statut, ExecutionStatus.error);
    expect(r.console, contains('Erreur d\'exécution'));
    expect(r.console, isNot(contains('Exécution refusée')));
  });
}
