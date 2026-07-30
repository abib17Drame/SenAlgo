import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senalgo/state/execution_provider.dart';
import 'package:senalgo/ui/widgets/app_toolbar.dart';

/// Affiche la barre d'outils dans l'état d'exécution donné, sur un écran large
/// pour que les libellés des boutons soient rendus.
Future<void> _afficherBarre(WidgetTester tester, ExecutionStatus statut) async {
  tester.view.physicalSize = const Size(1600, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      appBar: AppToolbar(
        isMobile: false,
        isCompact: false,
        executionState: ExecutionState(status: statut),
        autoPlayEnabled: false,
        examplesMenu: const SizedBox.shrink(),
        onOpenFile: () {},
        onSaveFile: () {},
        onNewFile: () {},
        onClearCode: () {},
        onShowPython: () {},
        onStop: () {},
        onStep: () {},
        onToggleAutoPlay: () {},
        onRunStepByStep: () {},
        onRun: () {},
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  testWidgets("au repos, aucune commande d'exécution en cours n'est visible", (tester) async {
    await _afficherBarre(tester, ExecutionStatus.idle);
    expect(find.text('ARRÊTER'), findsNothing);
    expect(find.text('SUIVANT'), findsNothing);
    expect(find.text('AUTO'), findsNothing);
    expect(find.text('PAS À PAS'), findsOneWidget);
  });

  testWidgets('pendant une exécution normale, seul ARRÊTER apparaît', (tester) async {
    await _afficherBarre(tester, ExecutionStatus.running);

    // Le point de la correction : « Suivant » et « Auto » ne pilotent que le
    // pas-à-pas. Les afficher ici donnerait des boutons actifs sans effet.
    expect(find.text('ARRÊTER'), findsOneWidget);
    expect(find.text('SUIVANT'), findsNothing);
    expect(find.text('AUTO'), findsNothing);
    expect(find.text('PAS À PAS'), findsOneWidget);
  });

  testWidgets('en pas-à-pas, les trois commandes sont là', (tester) async {
    await _afficherBarre(tester, ExecutionStatus.stepping);
    expect(find.text('ARRÊTER'), findsOneWidget);
    expect(find.text('SUIVANT'), findsOneWidget);
    expect(find.text('AUTO'), findsOneWidget);
    expect(find.text('PAS À PAS'), findsNothing);
  });

  testWidgets("en attente de saisie, on peut arrêter mais pas avancer", (tester) async {
    await _afficherBarre(tester, ExecutionStatus.waitingForInput);
    expect(find.text('ARRÊTER'), findsOneWidget);
    expect(find.text('SUIVANT'), findsOneWidget);

    // Avancer n'aurait pas de sens tant que la valeur n'est pas saisie.
    final suivant = tester.widget<ElevatedButton>(
      find.ancestor(of: find.text('SUIVANT'), matching: find.byType(ElevatedButton)),
    );
    expect(suivant.onPressed, isNull);
  });

  testWidgets('après la fin, la barre revient à son état de repos', (tester) async {
    await _afficherBarre(tester, ExecutionStatus.finished);
    expect(find.text('ARRÊTER'), findsNothing);
    expect(find.text('SUIVANT'), findsNothing);
    expect(find.text('PAS À PAS'), findsOneWidget);
  });

  testWidgets('le bouton ARRÊTER déclenche bien son action', (tester) async {
    var arrets = 0;
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        appBar: AppToolbar(
          isMobile: false,
          isCompact: false,
          executionState: ExecutionState(status: ExecutionStatus.running),
          autoPlayEnabled: false,
          examplesMenu: const SizedBox.shrink(),
          onOpenFile: () {},
          onSaveFile: () {},
          onNewFile: () {},
          onClearCode: () {},
          onShowPython: () {},
          onStop: () => arrets++,
          onStep: () {},
          onToggleAutoPlay: () {},
          onRunStepByStep: () {},
          onRun: () {},
        ),
      ),
    ));
    await tester.pump();

    await tester.tap(find.text('ARRÊTER'));
    expect(arrets, 1);
  });
}
