import 'package:senalgo/ui/services/algo_file_service.dart';
import 'package:test/test.dart';

void main() {
  group('Nom de fichier proposé à la sauvegarde', () {
    test("reprend le nom de l'algorithme", () {
      expect(
        AlgoFileService.suggestedFileName('ALGORITHME TriABulle\nDEBUT\nFIN'),
        equals('TriABulle.algo'),
      );
    });

    test('accepte les accents et les chiffres', () {
      expect(
        AlgoFileService.suggestedFileName('Algorithme Exercice2Réussi\nDEBUT\nFIN'),
        equals('Exercice2Réussi.algo'),
      );
    });

    test('ignore la casse du mot-clé', () {
      expect(
        AlgoFileService.suggestedFileName('algorithme MonAlgo\nDEBUT\nFIN'),
        equals('MonAlgo.algo'),
      );
    });

    test('retombe sur un nom par défaut sans déclaration', () {
      expect(
        AlgoFileService.suggestedFileName('DEBUT\n  ecrire("bonjour")\nFIN'),
        equals('mon_algorithme.algo'),
      );
    });
  });
}
