import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senalgo/core/lexer/lexer.dart';
import 'package:senalgo/core/parser/parser.dart';
import 'package:senalgo/state/execution_provider.dart';

void main() {
  test('Le programme par défaut ne contient pas de saut de ligne parasite', () {
    // Régression : le texte était défini dans une chaîne Dart """...""" non
    // brute, qui interprète les échappements. Le "\n" destiné au programme
    // SenAlgo devenait un vrai saut de ligne, coupant l'appel à ecrire en
    // deux dans l'éditeur. Le littéral doit rester visible tel quel.
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final source = container.read(sourceCodeProvider);

    expect(source.split('\n').length, equals(9));
    expect(source, contains(r'"\n")'));
  });

  test('Le programme par défaut est syntaxiquement valide', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final source = container.read(sourceCodeProvider);

    expect(() => Parser(Lexer(source).scanTokens()).parse(), returnsNormally);
  });
}
