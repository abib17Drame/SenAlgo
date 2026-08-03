import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:senalgo/state/execution_provider.dart';
import 'package:senalgo/ui/widgets/console_panel.dart';

/// Ce que le bouton a réellement déposé dans le presse-papier, ou `null` si
/// rien n'a été copié. Le canal système est simulé : en test il n'y a pas de
/// presse-papier, et sans ce relais la copie échouerait silencieusement.
String? _pressePapier;

/// Affiche la console avec [sorties] déjà écrites dedans, clique le bouton
/// de copie, et laisse le temps au message de confirmation d'apparaître.
Future<void> _copier(WidgetTester tester, List<String> sorties) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  _pressePapier = null;
  tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.setData') {
      _pressePapier = call.arguments['text'] as String;
    }
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, null));

  final container = ProviderContainer();
  addTearDown(container.dispose);
  for (final texte in sorties) {
    container.read(consoleProvider.notifier).addLine(texte);
  }

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(
      home: Scaffold(body: ConsolePanel(showVariables: false)),
    ),
  ));
  await tester.pump();

  await tester.tap(find.byTooltip('Copier la console'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('la copie reprend la sortie telle quelle', (tester) async {
    await _copier(tester, ['La somme est 15\n']);
    expect(_pressePapier, 'La somme est 15\n');
  });

  testWidgets("une seule ligne affichée est annoncée au singulier", (tester) async {
    await _copier(tester, ['La somme est 15\n']);
    expect(find.text('1 ligne copiée'), findsOneWidget);
  });

  // Le dernier élément de `lines` est la ligne en cours, vide dès qu'un
  // retour à la ligne l'a terminée. Compter les éléments annoncerait ici
  // quatre lignes pour trois affichées.
  testWidgets('le compte annoncé est celui des lignes visibles', (tester) async {
    await _copier(tester, ['un\n', 'deux\n', 'trois\n']);
    expect(find.text('3 lignes copiées'), findsOneWidget);
  });

  testWidgets("une ligne sans retour à la ligne compte quand même", (tester) async {
    await _copier(tester, ['sans retour']);
    expect(find.text('1 ligne copiée'), findsOneWidget);
    expect(_pressePapier, 'sans retour');
  });

  testWidgets('une console vide ne copie rien et le dit', (tester) async {
    await _copier(tester, []);
    expect(_pressePapier, isNull);
    expect(find.text('Console vide : rien à copier'), findsOneWidget);
  });
}
