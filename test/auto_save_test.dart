import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
}
