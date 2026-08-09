import 'package:flutter_test/flutter_test.dart';
import 'package:highlight/highlight_core.dart';
import 'package:senalgo/ui/editor_highlight.dart';

/// La couleur donnée à [mot] dans [source], ou `null` s'il n'en reçoit aucune.
String? couleurDe(String source, String mot) {
  final resultat = highlight.parse(source, language: 'senalgo');
  String? trouvee;

  void parcourir(List<Node> noeuds, String? classe) {
    for (final noeud in noeuds) {
      if (noeud.value != null && noeud.value!.contains(mot)) {
        trouvee ??= classe;
      }
      if (noeud.children != null) {
        parcourir(noeud.children!, noeud.className ?? classe);
      }
    }
  }

  parcourir(resultat.nodes!, null);
  return trouvee;
}

void main() {
  setUpAll(() => highlight.registerLanguage('senalgo', SenAlgoMode.grammaire));

  group("l'apostrophe de JUSQU'À n'ouvre pas un caractère", () {
    const boucle = "REPETER\n  x <- x + 1\nJUSQU'À x >= 5\nFIN";

    test("JUSQU'À est colorié comme un mot-clé", () {
      expect(couleurDe(boucle, "JUSQU'À"), 'keyword');
    });

    test('ce qui suit garde sa propre couleur', () {
      expect(couleurDe(boucle, '5'), 'number');
      expect(couleurDe(boucle, 'FIN'), 'keyword');
    });

    test('les quatre écritures sont coloriées pareil', () {
      for (final ecriture in ["JUSQU'À", "JUSQU'A", 'JUSQUÀ', 'JUSQUA']) {
        expect(couleurDe('REPETER\n$ecriture x > 2', ecriture), 'keyword',
            reason: ecriture);
      }
    });
  });

  group('un vrai caractère reste colorié', () {
    test("'o' est vu comme un littéral", () {
      expect(couleurDe("c <- 'o'", "'o'"), 'string');
    });

    test("une séquence d'échappement compte pour une lettre", () {
      expect(couleurDe(r"c <- '\n'", r"'\n'"), 'string');
    });

    test('un caractère laissé ouvert ne colorie pas la suite', () {
      expect(couleurDe("c <- 'a\nFIN", 'FIN'), 'keyword');
    });

    test('une chaîne entre guillemets reste une chaîne', () {
      expect(couleurDe('ecrire("bonjour")', '"bonjour"'), 'string');
    });
  });

  group('les mots-clés accentués sont coloriés', () {
    for (final mot in ['début', 'répéter', 'réel', 'booléen', 'chaîne', 'procédure']) {
      test(mot, () => expect(couleurDe('$mot ', mot), 'keyword'));
    }

    test('à dans une boucle POUR', () {
      expect(couleurDe('POUR i ALLANT DE 1 à 10 FAIRE', 'à'), 'keyword');
    });

    test('donnée-résultat colorie ses deux mots', () {
      const entete = 'PROCEDURE Echanger(donnée-résultat a : entier)';
      expect(couleurDe(entete, 'donnée'), 'keyword');
      expect(couleurDe(entete, 'résultat'), 'keyword');
    });
  });

  test('un commentaire reste un commentaire', () {
    expect(couleurDe('x <- 1 // note\n', '// note'), 'comment');
    expect(couleurDe('{ note }\n', '{ note }'), 'comment');
  });
}
