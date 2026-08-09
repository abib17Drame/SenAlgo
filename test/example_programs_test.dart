import 'package:senalgo/core/interpreter/interpreter.dart';
import 'package:senalgo/core/lexer/lexer.dart';
import 'package:senalgo/core/parser/parser.dart';
import 'package:senalgo/ui/examples/example_programs.dart';
import 'package:test/test.dart';

void main() {
  test('Le menu propose bien 19 exemples, tous nommés', () {
    expect(kExamplePrograms, hasLength(19));
    for (final exemple in kExamplePrograms) {
      expect(exemple.title.trim(), isNotEmpty);
      expect(exemple.code.trim(), isNotEmpty);
    }
  });

  group('Chaque exemple du menu est syntaxiquement valide', () {
    // Ces programmes sont proposés à des étudiants comme modèles : un exemple
    // qui ne compile pas est pire que pas d'exemple du tout. Ils étaient
    // enfermés dans une méthode privée de l'écran et donc intestables.
    for (final exemple in kExamplePrograms) {
      test(exemple.title, () {
        expect(
          () => Parser(Lexer(exemple.code).scanTokens()).parse(),
          returnsNormally,
        );
      });
    }
  });

  group("Aucun exemple ne contient de saut de ligne parasite", () {
    // Le "\n" écrit dans un appel à ecrire doit rester un littéral à deux
    // caractères ; s'il devient un vrai saut de ligne, l'instruction se
    // retrouve coupée en deux dans l'éditeur.
    for (final exemple in kExamplePrograms) {
      test(exemple.title, () {
        for (final ligne in exemple.code.split('\n')) {
          final guillemets = '"'.allMatches(ligne).length;
          expect(
            guillemets.isEven,
            isTrue,
            reason: 'chaîne non fermée sur la ligne : $ligne',
          );
        }
      });
    }
  });

  group("Le \\n des exemples passe bien à la ligne", () {
    // Écrit « \\n » dans le fichier, l'exemple affichait « \n » en toutes
    // lettres au lieu de revenir à la ligne.
    for (final exemple in kExamplePrograms) {
      test(exemple.title, () {
        expect(exemple.code.contains(r'\\n'), isFalse);
      });
    }
  });

  group('Les exemples de sous-programmes produisent le bon résultat', () {
    Future<String> executer(String source, List<String> saisies) async {
      var sortie = '';
      var i = 0;
      final programme = Parser(Lexer(source).scanTokens()).parse();
      await Interpreter(
        onPrint: (m) => sortie += m,
        onRead: () async => i < saisies.length ? saisies[i++] : '0',
      ).interpret(programme);
      return sortie;
    }

    String codeDe(String titre) =>
        kExamplePrograms.firstWhere((e) => e.title.startsWith(titre)).code;

    test("Rectangle d'étoiles", () async {
      final s = await executer(codeDe("Rectangle d'étoiles"), ['4', '2']);
      expect(s, endsWith('****\n****\n'));
    });

    test('Saisie contrôlée', () async {
      final s = await executer(codeDe('Saisie contrôlée'), ['-3', '9']);
      expect(s, endsWith('Vous avez saisi 9\n'));
    });

    test('Mini et maxi', () async {
      final s = await executer(codeDe('Mini et maxi'), ['12', '5', '18', '7', '9']);
      expect(s, contains('La plus haute est 18.0'));
      expect(s, contains('La plus basse est 5.0'));
    });

    test('Tri par échange', () async {
      final s = await executer(codeDe('Tri par échange'), ['5', '3', '9', '1', '7']);
      expect(s, endsWith('1 3 5 7 9 \n'));
    });
  });
}
