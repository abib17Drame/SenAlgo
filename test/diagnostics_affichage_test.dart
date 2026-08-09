import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senalgo/main.dart';
import 'package:senalgo/state/execution_provider.dart';
import 'package:senalgo/ui/screens/main_screen.dart';
import 'package:senalgo/ui/theme.dart';
import 'package:senalgo/ui/widgets/diagnostics_badge.dart';

Future<void> afficher(WidgetTester tester, Size taille) async {
  tester.view.physicalSize = taille;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(const SenAlgoApp());
  await tester.pumpAndSettle();
}

/// Monte l'écran avec un conteneur qu'on garde sous la main, pour pouvoir
/// provoquer une erreur d'exécution sans passer par l'éditeur.
Future<ProviderContainer> afficherPilotable(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final container = ProviderContainer();
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(theme: SenAlgoTheme.darkTheme, home: const MainScreen()),
  ));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  // Le badge était affiché deux fois sur écran large, au-dessus de l'éditeur
  // et dans la barre du bas, avec exactement le même texte.
  testWidgets('un seul badge de diagnostics sur écran large', (tester) async {
    await afficher(tester, const Size(1400, 900));
    expect(find.byType(DiagnosticsBadge), findsOneWidget);
  });

  testWidgets('un seul badge de diagnostics sur téléphone', (tester) async {
    await afficher(tester, const Size(390, 844));
    expect(find.byType(DiagnosticsBadge), findsOneWidget);
  });

  testWidgets('le badge est au-dessus de l\'éditeur, pas en bas', (tester) async {
    await afficher(tester, const Size(1400, 900));
    final position = tester.getCenter(find.byType(DiagnosticsBadge));
    expect(position.dy, lessThan(450));
  });

  // Un bandeau rouge répétait le message par-dessus la barre du bas.
  testWidgets('une erreur ne fait pas surgir de bandeau', (tester) async {
    final container = await afficherPilotable(tester);
    container.read(executionProvider.notifier).setStatus(
          ExecutionStatus.error,
          error: "la variable 'x' n'est pas déclarée.",
        );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(SnackBar), findsNothing);
    expect(find.textContaining("n'est pas déclarée"), findsNothing);
  });

  testWidgets("la barre du bas nomme l'échec sans recopier le message",
      (tester) async {
    final container = await afficherPilotable(tester);
    container.read(executionProvider.notifier).setStatus(
          ExecutionStatus.error,
          error: "la variable 'x' n'est pas déclarée.",
          refuseAvantDemarrage: true,
        );
    await tester.pump();

    expect(find.text('Exécution refusée'), findsOneWidget);
  });

  testWidgets("une erreur survenue en route se distingue d'un refus",
      (tester) async {
    final container = await afficherPilotable(tester);
    container.read(executionProvider.notifier).setStatus(
          ExecutionStatus.error,
          error: 'Division par zéro.',
        );
    await tester.pump();

    expect(find.text("Erreur d'exécution"), findsOneWidget);
  });
}
