import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senalgo/main.dart';

/// Tailles d'écran représentatives. Un débordement de `RenderFlex` lève une
/// erreur en mode debug, que `flutter_test` transforme en échec : ces tests
/// suffisent donc à garantir qu'aucun panneau ne déborde.
const _tailles = <String, Size>{
  'grand écran (1920x1080)': Size(1920, 1080),
  'ordinateur portable (1280x800)': Size(1280, 800),
  'fenêtre étroite, juste au-dessus du seuil mobile (820x600)': Size(820, 600),
  'tablette en mode portrait (768x1024)': Size(768, 1024),
  'téléphone (390x844)': Size(390, 844),
  'très petit téléphone (320x568)': Size(320, 568),
};

void main() {
  for (final entry in _tailles.entries) {
    testWidgets('Aucun débordement : ${entry.key}', (tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const SenAlgoApp());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('La barre de séparation ne peut pas écraser un panneau', (tester) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const SenAlgoApp());
    await tester.pumpAndSettle();

    // On tire la poignée verticale à fond vers la gauche, bien au-delà de la
    // largeur de la fenêtre : le panneau doit s'arrêter sur son minimum au
    // lieu de disparaître ou de faire déborder son voisin.
    final poignee = find.byType(MouseRegion).evaluate().where((e) {
      final region = e.widget as MouseRegion;
      return region.cursor == SystemMouseCursors.resizeLeftRight;
    });
    expect(poignee, isNotEmpty, reason: 'poignée de redimensionnement introuvable');

    await tester.drag(find.byWidget(poignee.first.widget), const Offset(-5000, 0));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.drag(find.byWidget(poignee.first.widget), const Offset(5000, 0));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
