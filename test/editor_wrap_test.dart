import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senalgo/main.dart';
import 'package:senalgo/ui/editor/wrapping_code_field.dart';

/// Une instruction volontairement bien plus large que n'importe quel écran.
const _ligneTresLongue = 'ALGORITHME Long\nDEBUT\n'
    '  ecrire("Voici une instruction particulierement longue qui depasse tres '
    'largement la largeur d un ecran de telephone et meme celle d un ecran '
    'd ordinateur portable ordinaire", a, b, c, d, e, f, g)\nFIN';

void main() {
  testWidgets('Une ligne très longue ne déborde pas sur un écran de téléphone', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const SenAlgoApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, _ligneTresLongue);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('Le retour à la ligne est actif par défaut', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const SenAlgoApp());
    await tester.pumpAndSettle();

    final champ = tester.widget<WrappingCodeField>(find.byType(WrappingCodeField));
    expect(champ.wrap, isTrue);
  });

  testWidgets('Le bouton bascule entre retour à la ligne et défilement horizontal', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const SenAlgoApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, _ligneTresLongue);
    await tester.pumpAndSettle();

    // Bascule vers le défilement horizontal.
    await tester.tap(find.byIcon(Icons.wrap_text));
    await tester.pumpAndSettle();
    expect(tester.widget<WrappingCodeField>(find.byType(WrappingCodeField)).wrap, isFalse);
    expect(tester.takeException(), isNull);

    // Puis retour au retour à la ligne : les deux modes doivent tenir avec du
    // texte déjà saisi (le contrôleur de défilement horizontal n'existe que
    // dans l'un des deux, cf. le correctif dans wrapping_code_field.dart).
    await tester.tap(find.byIcon(Icons.swap_horiz));
    await tester.pumpAndSettle();
    expect(tester.widget<WrappingCodeField>(find.byType(WrappingCodeField)).wrap, isTrue);
    expect(tester.takeException(), isNull);
  });
}
