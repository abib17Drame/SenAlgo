import 'package:senalgo/core/analyzer/semantic_analyzer.dart';
import 'package:senalgo/core/analyzer/types.dart';
import 'package:senalgo/core/lexer/lexer.dart';
import 'package:senalgo/core/parser/parser.dart';
import 'package:senalgo/ui/examples/example_programs.dart';
import 'package:test/test.dart';

List<SemanticDiagnostic> _analyser(String source) =>
    SemanticAnalyzer().analyser(Parser(Lexer(source).scanTokens()).parse());

/// Comme [_avecVariables], mais sans donner de valeur aux variables : ce que
/// vérifient les tests sur les variables non initialisées.
List<SemanticDiagnostic> _brut(String corps) => _analyser('''
ALGORITHME T
VARIABLES
  n, m : entier
  s : chaine
  t : TABLEAU[1..5] DE entier
DEBUT
$corps
FIN
''');

/// Enveloppe [corps] dans un programme déclarant les variables usuelles, et
/// leur donne une valeur : les autres tests portent sur autre chose.
List<SemanticDiagnostic> _avecVariables(String corps) => _analyser('''
ALGORITHME T
VARIABLES
  n, m : entier
  r : reel
  s : chaine
  b : booleen
  t : TABLEAU[1..5] DE entier
DEBUT
  n <- 0
  m <- 0
  r <- 0
  s <- ""
  b <- vrai
$corps
FIN
''');

void main() {
  group('Aucun faux positif', () {
    // Le critère décisif : un analyseur qui crie au loup sur du code correct
    // est pire qu'une absence d'analyse, car il apprend à ignorer les
    // avertissements.
    for (final exemple in kExamplePrograms) {
      test('exemple « ${exemple.title} »', () {
        expect(_analyser(exemple.code), isEmpty);
      });
    }

    test('affecter un entier à un réel est légitime', () {
      expect(_avecVariables('  r <- 5'), isEmpty);
    });

    test('concaténer une chaîne et un nombre est légitime', () {
      expect(_avecVariables('  s <- "total : " + n'), isEmpty);
    });

    test('la variable de boucle POUR est déclarée implicitement', () {
      expect(_analyser('ALGORITHME T\nDEBUT\n POUR i DE 1 à 3 FAIRE\n ecrire(i)\n FINPOUR\nFIN'), isEmpty);
    });

    test('une saisie ne présume pas du type reçu', () {
      expect(_avecVariables('  lire(n)\n  lire(s)'), isEmpty);
    });

    test("un type non reconnu n'entraîne aucun signalement", () {
      expect(_analyser('ALGORITHME T\nVARIABLES x : machin\nDEBUT\n x <- 5\n ecrire(x)\nFIN'), isEmpty);
    });
  });

  group('Affectations', () {
    test('une chaîne dans un entier est signalée', () {
      final w = _avecVariables('  n <- "bonjour"');
      expect(w, hasLength(1));
      expect(w.first.message, contains('est un entier'));
      expect(w.first.message, contains('une chaîne'));
    });

    test('un réel dans un entier signale la perte de précision', () {
      expect(_avecVariables('  n <- 3.7').first.message, contains('perdrait la partie décimale'));
    });

    test('une variable non déclarée est signalée', () {
      expect(_avecVariables('  inconnue <- 5').first.message, contains("n'est pas déclarée"));
    });
  });

  group('Conditions', () {
    test('une condition de SI non booléenne est signalée', () {
      expect(_avecVariables('  SI n ALORS\n ecrire("x")\n FINSI').first.message,
          contains('vraie ou fausse'));
    });

    test('ET appliqué à des nombres est signalé', () {
      expect(_avecVariables('  b <- n ET m').first.message, contains('conditions vraies ou fausses'));
    });

    test('une condition correcte ne dit rien', () {
      expect(_avecVariables('  SI n > 0 ET b ALORS\n ecrire("x")\n FINSI'), isEmpty);
    });
  });

  group('Tableaux', () {
    test('un indice non entier est signalé', () {
      expect(_avecVariables('  t[s] <- 1').first.message, contains('indice de tableau'));
    });

    test('indexer ce qui n\'est pas un tableau est signalé', () {
      expect(_avecVariables('  n[1] <- 2').first.message, contains("n'est pas un tableau"));
    });

    test('un usage correct ne dit rien', () {
      expect(_avecVariables('  t[2] <- 7\n  n <- t[2]'), isEmpty);
    });
  });

  group('Appels', () {
    const avecFonction = '''
ALGORITHME T
FONCTION Carre(x : entier) : entier
DEBUT
  RETOURNER x * x
FIN

VARIABLES n : entier
DEBUT
''';

    test('un nombre d\'arguments incorrect est signalé', () {
      expect(_analyser('$avecFonction  n <- Carre(1, 2)\nFIN').first.message,
          contains('attend 1 argument'));
    });

    test('un appel correct ne dit rien', () {
      expect(_analyser('$avecFonction  n <- Carre(3)\nFIN'), isEmpty);
    });

    test('une fonction inconnue est signalée', () {
      expect(_avecVariables('  n <- Truc(1)').first.message, contains('ni une fonction'));
    });

    test('un paramètre de sortie doit recevoir une variable', () {
      const source = '''
ALGORITHME T
PROCEDURE Ech(resultat a : entier)
DEBUT
  a <- 1
FIN

VARIABLES n : entier
DEBUT
  Ech(1 + 2)
FIN
''';
      expect(_analyser(source).first.message, contains('paramètre de sortie'));
    });
  });

  group('Opérateurs entiers', () {
    test('MOD appliqué à un réel est signalé', () {
      expect(_avecVariables('  n <- r MOD 2').first.message, contains("s'applique à des entiers"));
    });

    test('DIV entre entiers ne dit rien', () {
      expect(_avecVariables('  n <- n DIV m'), isEmpty);
    });
  });

  group('Valeur de retour', () {
    test('un type de retour incompatible est signalé', () {
      const source = '''
ALGORITHME T
FONCTION F() : entier
DEBUT
  RETOURNER "texte"
FIN

DEBUT
  ecrire(F())
FIN
''';
      expect(_analyser(source).first.message, contains('déclare renvoyer'));
    });
  });

  group('Les avertissements portent une ligne exploitable', () {
    test('la ligne signalée est celle de la faute', () {
      // L'en-tête occupe 13 lignes, donc « n <- 1 » est en 14 et la faute en 15.
      final w = _avecVariables('  n <- 1\n  n <- "oops"');
      expect(w, hasLength(1));
      expect(w.first.line, equals(15));
    });
  });

  group('Normalisation des noms de types', () {
    test('accents, pluriels et « d\' » sont reconnus', () {
      expect(TypeSenAlgo.baseDepuisNom('entiers'), equals(TypeBase.entier));
      expect(TypeSenAlgo.baseDepuisNom('réel'), equals(TypeBase.reel));
      expect(TypeSenAlgo.baseDepuisNom("d'entier"), equals(TypeBase.entier));
      expect(TypeSenAlgo.baseDepuisNom('CHAÎNE'), equals(TypeBase.chaine));
      expect(TypeSenAlgo.baseDepuisNom('machin'), equals(TypeBase.inconnu));
    });

    test('entier est acceptable là où un réel est attendu, pas l\'inverse', () {
      expect(TypeSenAlgo.reel.accepte(TypeSenAlgo.entier), isTrue);
      expect(TypeSenAlgo.entier.accepte(TypeSenAlgo.reel), isFalse);
    });

    test('un type inconnu est toujours accepté', () {
      expect(TypeSenAlgo.entier.accepte(TypeSenAlgo.inconnu), isTrue);
      expect(TypeSenAlgo.inconnu.accepte(TypeSenAlgo.chaine), isTrue);
    });
  });

  group('Variables non initialisées', () {
    test('lire une variable jamais affectée est signalé', () {
      final d = _brut('  ecrire(n)');
      expect(d, hasLength(1));
      expect(d.single.message, contains("'n' est utilisée avant"));
    });

    test('la valeur par défaut annoncée est celle du type', () {
      expect(_brut('  ecrire(n)').single.message, contains('elle vaut 0.'));
      expect(_brut('  ecrire(s)').single.message, contains('la chaîne vide'));
    });

    test("c'est un avertissement, pas une erreur", () {
      expect(_brut('  ecrire(n)').single.estErreur, isFalse);
    });

    test('un total jamais mis à zéro est signalé', () {
      expect(_brut('  n <- n + 1').single.message, contains("'n' est utilisée avant"));
    });

    test('affecter avant de lire ne dit rien', () {
      expect(_brut('  n <- 5\n  ecrire(n)'), isEmpty);
    });

    test('une saisie remplit la variable', () {
      expect(_brut('  lire(n)\n  ecrire(n)'), isEmpty);
    });

    test('un tableau déclaré est tenu pour rempli', () {
      expect(_brut('  ecrire(t[1])'), isEmpty);
    });

    test('la variable de boucle du POUR est remplie', () {
      expect(_brut('  POUR n ALLANT DE 1 à 3 FAIRE\n ecrire(n)\n FINPOUR'), isEmpty);
    });

    // L'analyse ne suit pas les chemins d'exécution : dès qu'une valeur a pu
    // être donnée, elle se tait plutôt que d'accuser à tort.
    test('une affectation dans une seule branche suffit à taire le doute', () {
      expect(_brut('  SI vrai ALORS\n n <- 1\n FINSI\n ecrire(n)'), isEmpty);
    });

    test("la même variable ne réclame qu'un seul avertissement", () {
      expect(_brut('  ecrire(n)\n  ecrire(n)\n  ecrire(n)'), hasLength(1));
    });

    // Un paramètre 'résultat' écrit dans la variable de l'appelant : la passer
    // sans valeur est le fonctionnement normal, pas une faute.
    test("un paramètre 'résultat' remplit la variable passée", () {
      expect(
        _analyser('ALGORITHME T\n'
            'PROCEDURE Remplir(résultat x : entier)\n'
            'DEBUT\n x <- 7\nFIN\n'
            'VARIABLES n : entier\n'
            'DEBUT\n Remplir(n)\n ecrire(n)\nFIN'),
        isEmpty,
      );
    });

    test('une fonction sans RETOURNER est refusée', () {
      final d = _analyser('ALGORITHME T\n'
          'FONCTION F(n : entier) : entier\n'
          'DEBUT\n ecrire(n)\nFIN\n'
          'DEBUT\n ecrire(F(1))\nFIN');
      expect(d.where((x) => x.estErreur), hasLength(1));
      expect(d.first.message, contains('ne renvoie jamais de valeur'));
    });

    test('un RETOURNER caché dans un SI suffit', () {
      expect(
        _analyser('ALGORITHME T\n'
            'FONCTION F(n : entier) : entier\n'
            'DEBUT\n SI n > 0 ALORS\n RETOURNER 1\n FINSI\n RETOURNER 0\nFIN\n'
            'DEBUT\n ecrire(F(1))\nFIN'),
        isEmpty,
      );
    });

    test("un paramètre 'donnée-résultat' apporte une valeur", () {
      expect(
        _analyser('ALGORITHME T\n'
            'PROCEDURE Doubler(donnée-résultat x : entier)\n'
            'DEBUT\n x <- x * 2\nFIN\n'
            'VARIABLES n : entier\n'
            'DEBUT\n n <- 3\n Doubler(n)\nFIN'),
        isEmpty,
      );
    });
  });

  group('Une procédure ne renvoie rien', () {
    const procedure = '''
ALGORITHME T
PROCEDURE ok()
DEBUT
  ecrire("alors")
FIN
VARIABLES n : entier
DEBUT
''';

    test('appelée seule, elle est à sa place', () {
      expect(_analyser('$procedure  ok()\nFIN'), isEmpty);
    });

    test('affichée, elle est refusée', () {
      final d = _analyser('$procedure  ecrire(ok())\nFIN');
      expect(d.where((x) => x.estErreur), hasLength(1));
      expect(d.first.message, contains('est une procédure'));
    });

    test('affectée, elle est refusée', () {
      expect(_analyser('$procedure  n <- ok()\nFIN').first.message,
          contains('est une procédure'));
    });

    test('dans un calcul, elle est refusée', () {
      expect(_analyser('$procedure  n <- 1 + ok()\nFIN').first.message,
          contains('est une procédure'));
    });

    test('une fonction appelée seule reste permise', () {
      const source = '''
ALGORITHME T
FONCTION f() : entier
DEBUT
  RETOURNER 1
FIN
DEBUT
  f()
FIN''';
      expect(_analyser(source), isEmpty);
    });
  });
}
