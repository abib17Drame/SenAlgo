import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senalgo/main.dart';
import 'package:senalgo/ui/editor/wrapping_code_field.dart';
import 'package:senalgo/ui/editor_highlight.dart';

const _programme = '''ALGORITHME MonAlgo
VARIABLES
  a, b, s: entier
DEBUT
  a <- 5
FIN''';

/// Le contrôleur réellement utilisé par l'écran, avec ses raccourcis.
Future<CodeController> editeur(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(const SenAlgoApp());
  await tester.pumpAndSettle();

  return tester
      .widget<WrappingCodeField>(find.byType(WrappingCodeField))
      .controller;
}

/// Déclenche l'action associée à [nom] sur le contrôleur, comme le ferait la
/// touche correspondante.
void declencher(CodeController c, String nom) {
  final type = c.actions.keys.firstWhere((k) => k.toString() == nom);
  // ignore: invalid_use_of_protected_member
  c.actions[type]!.invoke(const _IntentBidon());
}

class _IntentBidon extends Intent {
  const _IntentBidon();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Entrée indente un bloc et place le curseur dans son corps', (tester) async {
    final c = await editeur(tester);
    c.fullText = 'ALGORITHME T\nDEBUT\n  SI vrai ALORS\nFIN';
    final offset = c.text.indexOf('ALORS') + 'ALORS'.length;
    c.selection = TextSelection.collapsed(offset: offset);
    c.popupController.hide();

    declencher(c, 'EnterKeyIntent');
    await tester.pump();

    expect(c.text, contains('  SI vrai ALORS\n    \n  FinSi'));
    expect(c.selection.baseOffset, offset + 5);
  });

  testWidgets('Entrée au clavier conserve le curseur dans le bloc indenté', (tester) async {
    final c = await editeur(tester);
    c.fullText = 'ALGORITHME T\nDEBUT\n  SI vrai ALORS\nFIN';
    final offset = c.text.indexOf('ALORS') + 5;
    await tester.tap(find.byType(TextField).first);
    c.selection = TextSelection.collapsed(offset: offset);
    c.popupController.hide();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(c.text, contains('  SI vrai ALORS\n    \n  FinSi'));
    expect(c.selection.baseOffset, offset + 5);
  });

  group('Un popup périmé ne réécrit pas le programme', () {
    // insertSelectedWord remplace tout le mot sous le curseur. Le popup garde
    // ses suggestions après avoir été masqué : validées au mauvais moment,
    // elles écrasaient un mot du programme par un autre.
    for (final touche in ['EnterKeyIntent', 'TabKeyIntent']) {
      testWidgets('$touche : une suggestion sans rapport est ignorée',
          (tester) async {
        final c = await editeur(tester);
        c.fullText = _programme;
        c.selection = const TextSelection.collapsed(offset: 10);
        c.popupController.show(['ME']);

        declencher(c, touche);
        await tester.pump();

        expect(c.text, contains('ALGORITHME'));
      });

      testWidgets('$touche : une suggestion vide ne supprime pas le mot',
          (tester) async {
        final c = await editeur(tester);
        c.fullText = _programme;
        c.selection = const TextSelection.collapsed(offset: 10);
        c.popupController.show(['']);

        declencher(c, touche);
        await tester.pump();

        expect(c.text, contains('ALGORITHME'));
      });
    }
  });

  group("La complétion légitime marche toujours", () {
    testWidgets('une suggestion qui prolonge le mot est insérée',
        (tester) async {
      final c = await editeur(tester);
      c.fullText = 'ALGORITHME T\nDEBUT\n  TANT\nFIN';
      c.selection = TextSelection.collapsed(offset: c.text.indexOf('TANT') + 4);
      c.popupController.show(['TANTQUE']);

      declencher(c, 'EnterKeyIntent');
      await tester.pump();

      expect(c.text, contains('TANTQUE'));
    });

    testWidgets('la casse ne bloque pas la complétion', (tester) async {
      final c = await editeur(tester);
      c.fullText = 'ALGORITHME T\nDEBUT\n  tant\nFIN';
      c.selection = TextSelection.collapsed(offset: c.text.indexOf('tant') + 4);
      c.popupController.show(['TANTQUE']);

      declencher(c, 'EnterKeyIntent');
      await tester.pump();

      expect(c.text, contains('TANTQUE'));
    });
  });

  test('la grammaire de coloration reste utilisable hors écran', () {
    // Garde-fou : les tests ci-dessus montent l'app entière, celui-ci vérifie
    // que le contrôleur seul se construit.
    final c = CodeController(text: 'DEBUT', language: SenAlgoMode.grammaire);
    expect(c.text, equals('DEBUT'));
  });
}
