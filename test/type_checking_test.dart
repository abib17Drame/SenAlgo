// ignore_for_file: unnecessary_string_escapes
import 'package:senalgo/core/analyzer/semantic_analyzer.dart';
import 'package:senalgo/core/interpreter/interpreter.dart';
import 'package:senalgo/core/lexer/lexer.dart';
import 'package:senalgo/core/parser/parser.dart';
import 'package:test/test.dart';

/// Enveloppe [corps] dans un programme déclarant les variables usuelles.
///
/// Les déclarations occupent les lignes 1 à 11, le corps commence donc à la
/// ligne 12 : les tests qui vérifient un numéro de ligne s'appuient dessus.
String _programme(String corps) => '''
ALGORITHME T
CONSTANTES
  PI = 3.14
VARIABLES
  n, m : entier
  r : reel
  s : chaine
  c : caractere
  b : booleen
  t : TABLEAU[1..5] DE entier
DEBUT
  ${corps.replaceAll('\n', '\n  ')}
FIN
''';

List<SemanticDiagnostic> _analyser(String corps) =>
    SemanticAnalyzer().analyser(Parser(Lexer(_programme(corps)).scanTokens()).parse());

List<SemanticDiagnostic> _erreurs(String corps) =>
    _analyser(corps).where((d) => d.estErreur).toList();

List<SemanticDiagnostic> _avertissements(String corps) =>
    _analyser(corps).where((d) => !d.estErreur).toList();

/// Exécute [corps] sans passer par l'analyse sémantique, pour observer ce que
/// fait l'interpréteur seul. [saisies] alimente les appels à `lire`.
Future<String> _executer(String corps, {List<String> saisies = const []}) async {
  final sortie = StringBuffer();
  var prochaine = 0;
  await Interpreter(
    onPrint: sortie.write,
    onRead: () async => prochaine < saisies.length ? saisies[prochaine++] : '0',
  ).interpret(Parser(Lexer(_programme(corps)).scanTokens()).parse());
  return sortie.toString();
}

/// Renvoie le message d'erreur levé par [corps], ou échoue si le programme
/// s'exécute sans broncher.
Future<String> _erreurExecution(String corps, {List<String> saisies = const []}) async {
  try {
    final sortie = await _executer(corps, saisies: saisies);
    fail("le programme aurait dû échouer, il a affiché « $sortie »");
  } catch (e) {
    return e.toString();
  }
}

void main() {
  group('classification des signalements', () {
    test('un mélange de types franc est une erreur', () {
      expect(_erreurs('n <- "bonjour"'), hasLength(1));
      expect(_erreurs('b <- 5'), hasLength(1));
      expect(_erreurs('s <- 5'), hasLength(1));
      expect(_erreurs('t <- 5'), hasLength(1));
    });

    test("une condition qui n'est pas booléenne est une erreur", () {
      expect(_erreurs('si n alors ecrire("x") finsi'), hasLength(1));
      expect(_erreurs('tantque n faire n <- n - 1 fintantque'), hasLength(1));
      expect(_erreurs('b <- non n'), hasLength(1));
    });

    test('un indice qui n\'est pas entier est une erreur', () {
      expect(_erreurs('t[r] <- 1'), hasLength(1));
      expect(_erreurs('t[s] <- 1'), hasLength(1));
    });

    test('un opérateur sur le mauvais type est une erreur', () {
      expect(_erreurs('n <- s * 3'), hasLength(1));
      expect(_erreurs('n <- 7 div 2.5'), hasLength(1));
      expect(_erreurs('b <- (n et m)'), hasLength(1));
    });

    test('affecter un réel à un entier est un avertissement, pas une erreur', () {
      // La partie décimale est perdue, mais l'opération a un sens défini et
      // l'exécution la réalise vraiment.
      expect(_erreurs('n <- 3.7'), isEmpty);
      expect(_avertissements('n <- 3.7'), hasLength(1));
      expect(_avertissements('n <- 3.7').single.message, contains('partie décimale'));
    });

    test('ranger un réel dans un tableau d\'entiers est un avertissement', () {
      expect(_erreurs('t[1] <- 3.7'), isEmpty);
      expect(_avertissements('t[1] <- 3.7'), hasLength(1));
    });

    test('une comparaison toujours fausse est un avertissement', () {
      // Le programme tourne et la comparaison a un résultat défini : elle est
      // fausse. C'est un doute sur l'intention, pas une impossibilité.
      expect(_erreurs('b <- (s = n)'), isEmpty);
      expect(_avertissements('b <- (s = n)'), hasLength(1));
    });

    test('un programme correct ne signale rien du tout', () {
      expect(_analyser('n <- 5\nm <- n * 2\necrire(m)'), isEmpty);
    });

    test('le signalement porte le numéro de ligne du fautif', () {
      expect(_erreurs('n <- 1\nn <- "x"').single.line, equals(13));
    });
  });

  group('apostrophes et guillemets', () {
    // Le cours distingue les deux : rep <- 'o' pour un caractère,
    // nom <- "moussa" pour une chaîne.
    test("'o' est un caractère, \"moussa\" est une chaîne", () async {
      expect(_analyser("c <- 'o'"), isEmpty);
      expect(_analyser('s <- "moussa"'), isEmpty);
      expect(await _executer("c <- 'o'\necrire(c)"), equals('o'));
    });

    test('une chaîne ne rentre pas dans un caractère sans avertissement', () {
      expect(_avertissements('c <- "moussa"'), hasLength(1));
    });

    test("un caractère rentre dans une chaîne", () async {
      expect(_analyser("s <- 'o'"), isEmpty);
      expect(await _executer("s <- 'o'\necrire(s)"), equals('o'));
    });

    test('deux lettres entre apostrophes sont refusées à la lecture', () {
      // Le message vient de l'analyse lexicale : il doit remonter tel quel,
      // et pas être remplacé par un « Expression attendue » sans intérêt.
      expect(
        () => Parser(Lexer(_programme("c <- 'oui'")).scanTokens()).parse(),
        throwsA(allOf(
          contains("qu'une seule lettre"),
          contains('guillemets doubles'),
        )),
      );
    });

    test('des apostrophes vides sont refusées', () {
      expect(
        () => Parser(Lexer(_programme("c <- ''")).scanTokens()).parse(),
        throwsA(contains('ne peut pas être vide')),
      );
    });

    test("un échappement compte pour une seule lettre", () async {
      expect(await _executer("c <- '\\n'\necrire(\"[\", c, \"]\")"), equals('[\n]'));
    });

    test("l'apostrophe des mots-clés n'est pas confondue avec un caractère", () async {
      // JUSQU'À et « tableau d'entiers » contiennent une apostrophe : elle est
      // absorbée par l'identificateur, pas lue comme un début de littéral.
      expect(
        await _executer("n <- 0\nrepeter\n n <- n + 1\njusqu'à n >= 3\necrire(n)"),
        equals('3'),
      );
    });

    test('les caractères se comparent dans l\'ordre ASCII', () async {
      // Le cours : Z (90) est inférieur à a (97).
      expect(await _executer("b <- ('Z' < 'a')\necrire(b)"), equals('true'));
      expect(await _executer("b <- ('A' < 'B')\necrire(b)"), equals('true'));
    });
  });

  group('le type caractère reste utilisable', () {
    // Régression trouvée à l'usage : tout littéral textuel était typé
    // « chaîne », donc `c <- "a"` était une erreur bloquante et il devenait
    // impossible de donner la moindre valeur à une variable `caractere`.
    test("affecter une lettre entre apostrophes ne signale rien", () {
      expect(_analyser("c <- 'a'"), isEmpty);
    });

    test('les guillemets doubles avertissent sans bloquer', () async {
      // "a" est une chaîne d'une lettre : elle tient dans un caractère, mais
      // ce n'est pas la notation du cours, d'où le rappel.
      expect(_erreurs('c <- "a"'), isEmpty);
      expect(_avertissements('c <- "a"').single.message, contains('apostrophes'));
      expect(await _executer('c <- "a"\necrire(c)'), equals('a'));
    });

    test('un texte trop long avertit, et l\'exécution le refuse', () async {
      expect(_erreurs('c <- "abc"'), isEmpty);
      expect(_avertissements('c <- "abc"'), hasLength(1));

      // L'analyse ne connaît pas toujours la longueur, l'exécution si.
      expect(await _erreurExecution('c <- "abc"'), contains('en contient 3'));
    });

    test('affecter une chaîne de longueur inconnue avertit sans bloquer', () async {
      expect(_erreurs('s <- "z"\nc <- s'), isEmpty);
      expect(await _executer('s <- "z"\nc <- s\necrire(c)'), equals('z'));
    });

    test('concaténer deux caractères donne une chaîne', () async {
      // L'interpréteur le faisait déjà ; l'analyse le refusait.
      expect(_analyser("c <- 'a'\ns <- c + 'b'"), isEmpty);
      expect(await _executer("c <- 'a'\ns <- c + 'b'\necrire(s)"), equals('ab'));
    });

    test('mettre un nombre dans un caractère reste une erreur', () {
      expect(_erreurs('c <- 5'), hasLength(1));
    });

    test('la sévérité ne dépend pas de l\'endroit où la valeur entre', () {
      // Le même rétrécissement était traité en avertissement dans une
      // affectation et en erreur bloquante dans un appel.
      const entete = '''
ALGORITHME T
PROCEDURE P(x : caractere)
DEBUT
  ecrire(x)
FIN
PROCEDURE R(y : entier)
DEBUT
  ecrire(y)
FIN
VARIABLES
  c : caractere
  n : entier
  t : TABLEAU[1..3] DE entier
DEBUT
''';
      List<SemanticDiagnostic> analyserBrut(String corps) => SemanticAnalyzer()
          .analyser(Parser(Lexer('$entete  $corps\nFIN\n').scanTokens()).parse());

      for (final corps in ['c <- "ab"', 'P("ab")', 'n <- 1.5', 'R(1.5)', 't[1] <- 1.5']) {
        final d = analyserBrut(corps);
        expect(d, hasLength(1), reason: corps);
        expect(d.single.estErreur, isFalse, reason: corps);
      }
    });
  });

  group('constantes', () {
    test("réaffecter une constante est une erreur d'analyse", () {
      final e = _erreurs('PI <- 4');
      expect(e, hasLength(1));
      expect(e.single.message, contains('constante'));
    });

    test("réaffecter une constante est refusé à l'exécution", () async {
      expect(await _erreurExecution('PI <- 4'), contains('constante'));
    });

    test('lire une constante au clavier est refusé', () async {
      expect(await _erreurExecution('lire(PI)', saisies: ['5']), contains('constante'));
    });

    test('une constante reste lisible', () async {
      expect(await _executer('ecrire(PI)'), equals('3.14'));
    });
  });

  group('le type déclaré est respecté à l\'exécution', () {
    test('un réel affecté à un entier est tronqué', () async {
      // C'est exactement ce que l'avertissement annonce : la déclaration cesse
      // d'être décorative.
      expect(await _executer('n <- 3.7\necrire(n)'), equals('3'));
      expect(await _executer('n <- 7 / 2\necrire(n)'), equals('3'));
      expect(await _executer('n <- -3.7\necrire(n)'), equals('-3'));
    });

    test('une chaîne affectée à un entier arrête le programme', () async {
      final e = await _erreurExecution('n <- "abc"');
      expect(e, contains("'n' est un entier"));
      expect(e, contains('ligne 12'));
    });

    test('un entier affecté à un booléen arrête le programme', () async {
      expect(await _erreurExecution('b <- 5'), contains('vrai ou faux'));
    });

    test('un entier affecté à une chaîne arrête le programme', () async {
      expect(await _erreurExecution('s <- 5'), contains("'s' est une chaîne"));
    });

    test('une chaîne trop longue pour un caractère est refusée', () async {
      expect(await _erreurExecution('c <- "abc"'), contains('caractère'));
      expect(await _executer('c <- "a"\necrire(c)'), equals('a'));
    });

    test('un entier reste valide dans un réel', () async {
      expect(await _executer('r <- 5\necrire(r)'), equals('5'));
    });

    test('le type est aussi vérifié case par case dans un tableau', () async {
      // Le message nomme la case exacte, pas seulement le tableau.
      expect(await _erreurExecution('t[1] <- "abc"'), contains("'t[1]' est un entier"));
      expect(await _executer('t[1] <- 3.9\necrire(t[1])'), equals('3'));
    });

    test('le type est vérifié à la liaison des paramètres', () async {
      final source = '''
ALGORITHME T
FONCTION Double(x : entier) : entier
DEBUT
  RETOURNER x * 2
FIN
VARIABLES
  s : chaine
DEBUT
  s <- "texte"
  ecrire(Double(s))
FIN
''';
      try {
        await Interpreter(onPrint: (_) {}, onRead: () async => '0')
            .interpret(Parser(Lexer(source).scanTokens()).parse());
        fail('le programme aurait dû échouer');
      } catch (e) {
        expect(e.toString(), contains("paramètre 'x'"));
      }
    });
  });

  group('conditions', () {
    test('une condition entière est refusée en français', () async {
      final e = await _erreurExecution('n <- 5\nsi n alors ecrire("x") finsi');
      expect(e, contains('vraie ou fausse'));
      expect(e, contains('un entier'));
      // Le message de Dart ne doit jamais remonter jusqu'à l'utilisateur.
      expect(e, isNot(contains('subtype')));
    });

    test('une condition booléenne fonctionne normalement', () async {
      expect(await _executer('n <- 5\nsi n > 3 alors ecrire("ok") finsi'), equals('ok'));
    });
  });

  group('bornes et indices', () {
    test('un indice réel est refusé en français', () async {
      final e = await _erreurExecution('r <- 1.5\nt[r] <- 1');
      expect(e, contains("indice de 't'"));
      expect(e, isNot(contains('subtype')));
    });

    test('un pas nul dans un POUR est signalé', () async {
      expect(await _erreurExecution('pour n allant de 1 à 10 pas 0 faire\n ecrire(n)\nfinpour'),
          contains('pas'));
    });

    test('une boucle POUR normale reste intacte', () async {
      expect(await _executer('pour n allant de 1 à 3 faire\n ecrire(n)\nfinpour'), equals('123'));
    });
  });

  group('opérateurs', () {
    test('ET sur des entiers est refusé en français', () async {
      final e = await _erreurExecution('n <- 5\nm <- 3\nb <- (n et m)');
      expect(e, contains('vraie ou fausse'));
      expect(e, isNot(contains('subtype')));
    });

    test('ET court-circuité contrôle quand même son côté droit', () async {
      // `faux ET 5` : Dart s'arrêterait à gauche et ne verrait jamais le 5.
      expect(await _erreurExecution('b <- (1 > 2 et 5)'), contains('vraie ou fausse'));
    });

    test('DIV sur un réel est refusé à l\'exécution', () async {
      final e = await _erreurExecution('r <- 2.5\nn <- 7 div r');
      expect(e, contains("s'applique à des entiers"));
    });

    test('soustraire une chaîne est refusé en français', () async {
      final e = await _erreurExecution('n <- 5 - s');
      expect(e, contains("s'applique à des nombres"));
      expect(e, isNot(contains('NoSuchMethod')));
    });

    test('comparer deux chaînes fonctionne, dans l\'ordre alphabétique', () async {
      // Dart ne définit pas '<' sur String : sans traitement, ce programme
      // pourtant accepté par l'analyse plantait en anglais.
      expect(await _executer('b <- ("abc" < "abd")\necrire(b)'), equals('true'));
      expect(await _executer('b <- ("zoo" < "abc")\necrire(b)'), equals('false'));
    });

    test('comparer une chaîne et un nombre est refusé en français', () async {
      final e = await _erreurExecution('b <- (s < 5)');
      expect(e, contains('ne peut pas comparer'));
      expect(e, isNot(contains('NoSuchMethod')));
    });
  });

  group('fonctions intégrées', () {
    test('racine sur une chaîne est refusée en français', () async {
      final e = await _erreurExecution('r <- racine(s)');
      expect(e, contains("'racine' s'applique à un nombre"));
      expect(e, isNot(contains('subtype')));
    });

    test("racine d'un négatif est signalée plutôt que de rendre NaN", () async {
      expect(await _erreurExecution('r <- racine(-4)'), contains('négatif'));
    });

    test('abs sur une chaîne est refusée en français', () async {
      expect(await _erreurExecution('n <- abs(s)'), contains("'abs' s'applique à un nombre"));
    });
  });

  group('saisie au clavier', () {
    test("une saisie qui n'est pas un entier est refusée", () async {
      // Rendre 0 en silence ferait continuer le programme sur une valeur que
      // l'utilisateur n'a jamais donnée.
      final e = await _erreurExecution('lire(n)', saisies: ['douze']);
      expect(e, contains('Saisie invalide'));
      expect(e, contains('douze'));
    });

    test('une saisie valide est convertie', () async {
      expect(await _executer('lire(n)\necrire(n * 2)', saisies: ['21']), equals('42'));
      expect(await _executer('lire(r)\necrire(r)', saisies: ['1,5']), equals('1.5'));
      expect(await _executer('lire(b)\necrire(b)', saisies: ['vrai']), equals('true'));
    });

    test("une saisie booléenne incompréhensible est refusée", () async {
      expect(await _erreurExecution('lire(b)', saisies: ['peut-être']), contains('ni vrai ni faux'));
    });

    test('lire dans un tableau sans indiquer la case est refusé', () async {
      final e = await _erreurExecution('lire(t)', saisies: ['5']);
      expect(e, contains('tableau'));
      expect(e, contains('t[1]'));

      // Et l'analyse le voit sans avoir à lancer le programme.
      expect(_erreurs('lire(t)'), hasLength(1));
      expect(_erreurs('lire(PI)'), hasLength(1));
    });

    test('lire dans une case précise fonctionne', () async {
      expect(await _executer('lire(t[2])\necrire(t[2])', saisies: ['7']), equals('7'));
    });
  });
}
