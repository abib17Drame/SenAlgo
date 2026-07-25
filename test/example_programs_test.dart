import 'package:senalgo/core/lexer/lexer.dart';
import 'package:senalgo/core/parser/parser.dart';
import 'package:senalgo/ui/examples/example_programs.dart';
import 'package:test/test.dart';

void main() {
  test('Le menu propose bien 15 exemples, tous nommés', () {
    expect(kExamplePrograms, hasLength(15));
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
}
