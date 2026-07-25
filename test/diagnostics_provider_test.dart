import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senalgo/state/diagnostics_provider.dart';

Diagnostics _analyser(String source) {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  container.read(diagnosticsProvider.notifier).analyser(source);
  return container.read(diagnosticsProvider);
}

void main() {
  test('un programme correct ne signale rien', () {
    final d = _analyser('ALGORITHME T\nVARIABLES n : entier\nDEBUT\n n <- 5\n ecrire(n)\nFIN');
    expect(d.aUneErreur, isFalse);
    expect(d.aDesAvertissements, isFalse);
    expect(d.ligneAAtteindre, isNull);
  });

  test("une erreur de syntaxe est rapportée avec sa ligne", () {
    final d = _analyser('ALGORITHME T\nDEBUT\n SI vrai ALORS\n ecrire("x")\nFIN');
    expect(d.aUneErreur, isTrue);
    expect(d.errorLine, isNotNull);
    expect(d.ligneAAtteindre, equals(d.errorLine));
  });

  test('un avertissement sémantique est rapporté avec sa ligne', () {
    final d = _analyser('ALGORITHME T\nVARIABLES n : entier\nDEBUT\n n <- "texte"\nFIN');
    expect(d.aUneErreur, isFalse);
    expect(d.aDesAvertissements, isTrue);
    expect(d.warnings.single.line, equals(4));
    expect(d.ligneAAtteindre, equals(4));
  });

  test("une erreur de syntaxe masque les avertissements", () {
    // L'arbre est incomplet : les avertissements sémantiques n'auraient
    // aucun sens et induiraient en erreur.
    final d = _analyser('ALGORITHME T\nVARIABLES n : entier\nDEBUT\n n <- "texte"\n SI vrai ALORS\nFIN');
    expect(d.aUneErreur, isTrue);
    expect(d.warnings, isEmpty);
    expect(d.aDesAvertissements, isFalse);
  });

  test("une nouvelle analyse remplace la précédente", () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(diagnosticsProvider.notifier);

    notifier.analyser('ALGORITHME T\nVARIABLES n : entier\nDEBUT\n n <- "texte"\nFIN');
    expect(container.read(diagnosticsProvider).aDesAvertissements, isTrue);

    notifier.analyser('ALGORITHME T\nVARIABLES n : entier\nDEBUT\n n <- 5\nFIN');
    expect(container.read(diagnosticsProvider).aDesAvertissements, isFalse);
    expect(container.read(diagnosticsProvider).aUneErreur, isFalse);
  });
}
