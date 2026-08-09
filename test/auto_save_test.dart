import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:senalgo/main.dart';
import 'package:senalgo/ui/editor/wrapping_code_field.dart';
import 'package:senalgo/ui/services/auto_save_service.dart';

void main() {
  setUp(() {
    // Stockage en mémoire : les tests ne touchent pas au disque.
    SharedPreferences.setMockInitialValues({});
  });

  test("sans session précédente, rien n'est proposé", () async {
    expect(await AutoSaveService.reprendre(), isNull);
  });

  test('un programme enregistré est retrouvé à la session suivante', () async {
    const programme = 'ALGORITHME Repris\nDEBUT\n  ecrire("bonjour")\nFIN';
    await AutoSaveService.enregistrer(programme);
    expect(await AutoSaveService.reprendre(), programme);
  });

  test('le dernier enregistrement écrase le précédent', () async {
    await AutoSaveService.enregistrer('premier');
    await AutoSaveService.enregistrer('second');
    expect(await AutoSaveService.reprendre(), 'second');
  });

  test('un programme vide ne remplace pas le programme par défaut', () async {
    await AutoSaveService.enregistrer('   \n  \n ');
    expect(await AutoSaveService.reprendre(), isNull);
  });

  test('les accents et les retours à la ligne survivent', () async {
    const programme = 'ALGORITHME Accentué\nVARIABLES\n  é: réel\nDEBUT\n  é <- 1.5\nFIN';
    await AutoSaveService.enregistrer(programme);
    expect(await AutoSaveService.reprendre(), programme);
  });

  test('effacer supprime la reprise', () async {
    await AutoSaveService.enregistrer('quelque chose');
    await AutoSaveService.effacer();
    expect(await AutoSaveService.reprendre(), isNull);
  });

  group("Le programme repris arrive entier dans l'éditeur", () {
    // Le service rendait bien le texte, mais l'éditeur le recevait par une
    // affectation traitée comme une frappe : il en gardait un fragment, que
    // la sauvegarde automatique réenregistrait aussitôt. Le programme fondait
    // à chaque redémarrage.
    Future<String> reprisDansEditeur(WidgetTester tester, String programme) async {
      SharedPreferences.setMockInitialValues({
        'flutter.senalgo.programme_en_cours': programme,
      });
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(const SenAlgoApp());
      await tester.pumpAndSettle();

      return tester
          .widget<WrappingCodeField>(find.byType(WrappingCodeField))
          .controller
          .fullText;
    }

    testWidgets('un programme différent du programme par défaut', (tester) async {
      const programme = 'ALGORITHME Repris\n'
          'VARIABLES\n  x : entier\nDEBUT\n  x <- 42\n  ecrire(x)\nFIN';
      expect(await reprisDansEditeur(tester, programme), equals(programme));
    });

    testWidgets('un programme plus court que celui affiché au départ',
        (tester) async {
      const programme = 'ALGORITHME P\nDEBUT\nFIN';
      expect(await reprisDansEditeur(tester, programme), equals(programme));
    });

    testWidgets('un programme plus long, avec des accents', (tester) async {
      const programme = 'ALGORITHME Répétition\n'
          'VARIABLES\n  compteur, résultat : entier\nDEBUT\n'
          '  compteur <- 0\n  résultat <- 1\n'
          '  REPETER\n    compteur <- compteur + 1\n'
          "    résultat <- résultat * 2\n  JUSQU'À compteur >= 10\n"
          '  ecrire("2 puissance 10 vaut ", résultat)\nFIN';
      expect(await reprisDansEditeur(tester, programme), equals(programme));
    });
  });
}
