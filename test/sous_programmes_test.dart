import 'package:senalgo/core/analyzer/semantic_analyzer.dart';
import 'package:senalgo/core/interpreter/interpreter.dart';
import 'package:senalgo/core/lexer/lexer.dart';
import 'package:senalgo/core/parser/parser.dart';
import 'package:test/test.dart';

/// Exécute [source] en répondant [saisies] aux lectures, après avoir vérifié
/// que l'analyse sémantique laisse passer.
Future<String> executer(String source, [List<String> saisies = const []]) async {
  final programme = Parser(Lexer(source).scanTokens()).parse();
  final erreurs =
      SemanticAnalyzer().analyser(programme).where((d) => d.estErreur).toList();
  expect(erreurs, isEmpty, reason: erreurs.map((e) => '$e').join(' / '));

  var sortie = '';
  var i = 0;
  await Interpreter(
    onPrint: (m) => sortie += m,
    onRead: () async => i < saisies.length ? saisies[i++] : '0',
  ).interpret(programme);
  return sortie;
}

void main() {
  group("Écritures admises par l'énoncé", () {
    test('FinTQ ferme un TANT QUE', () async {
      expect(
        await executer('Algorithme T\nVariables n : entier\nDébut\n'
            'n <- 0\nTant que n < 3 Faire\nn <- n + 1\nFinTQ\nAfficher n\nFin'),
        equals('3'),
      );
    });

    test('Répeter avec un seul accent', () async {
      expect(
        await executer('Algorithme T\nVariables e : booléen\nDébut\n'
            "e <- vrai\nRépeter\ne <- faux\nJusqu'à non e\nAfficher \"fini\"\nFin"),
        equals('fini'),
      );
    });

    test('résultats au pluriel, plusieurs noms pour un type', () async {
      expect(
        await executer('Algorithme T\n'
            'Procédure mm (résultats a, b : entier)\n'
            'Début\na <- 1\nb <- 2\nFin\n'
            'Variables x, y : entier\n'
            'Début\nmm(x, y)\nAfficher x, y\nFin'),
        equals('12'),
      );
    });

    test('Saisir dans une case notée avec des parenthèses', () async {
      expect(
        await executer(
          'Algorithme T\nVariables t(1 : 2) : tableau d\'entiers\nDébut\n'
          'Saisir t(1)\nAfficher t(1)\nFin',
          ['7'],
        ),
        equals('7'),
      );
    });

    // « tableau d'entiers » donne le type « d'entiers » : sans normalisation
    // les cases valaient vide au lieu de zéro.
    test("un tableau d'entiers part de zéro", () async {
      expect(
        await executer('Algorithme T\nVariables t(1 : 2) : tableau d\'entiers\n'
            'Début\nAfficher t(1)\nFin'),
        equals('0'),
      );
    });
  });

  group('Si Alors sur une ligne, sans FinSi', () {
    test('la branche tient dans une instruction', () async {
      expect(
        await executer('Algorithme T\nVariables n : entier\nDébut\n'
            'n <- 5\nSi n > 1\nAlors Afficher "grand"\nFin'),
        equals('grand'),
      );
    });

    test('la condition fausse ne fait rien', () async {
      expect(
        await executer('Algorithme T\nVariables n : entier\nDébut\n'
            'n <- 0\nSi n > 1\nAlors Afficher "grand"\nAfficher "suite"\nFin'),
        equals('suite'),
      );
    });

    test('un Sinon court suit', () async {
      expect(
        await executer('Algorithme T\nVariables n : entier\nDébut\n'
            'n <- 0\nSi n > 1 Alors Afficher "grand" Sinon Afficher "petit"\nFin'),
        equals('petit'),
      );
    });

    test('deux Si courts se suivent sans se mélanger', () async {
      expect(
        await executer('Algorithme T\nVariables n : entier\nDébut\n'
            'n <- 5\n'
            'Si n > 1\nAlors Afficher "a"\n'
            'Si n > 4\nAlors Afficher "b"\n'
            'Fin'),
        equals('ab'),
      );
    });

    test('la forme en bloc avec FinSi reste intacte', () async {
      expect(
        await executer('Algorithme T\nVariables n : entier\nDébut\n'
            'n <- 5\nSi n > 1 ALORS\nAfficher "a"\nAfficher "b"\nFINSI\nFin'),
        equals('ab'),
      );
    });
  });

  group('Programmes complets', () {
    test('rectangle d\'étoiles, procédure avec un paramètre donnée', () async {
      const source = '''
Procédure ligne_Etoile (donnée nombre : entier)
Variables cpt : entier
Début
Pour cpt de 1 à nombre Faire
Afficher "*"
FinPour
Afficher "\\n"
Fin

Algorithme Rectangle_Etoile
Variables i, nlignes, netoiles : entier
Début
Saisir netoiles
Saisir nlignes
Pour i de 1 à nlignes Faire
ligne_Etoile (netoiles)
FinPour
Fin''';
      expect(await executer(source, ['3', '2']), equals('***\n***\n'));
    });

    test('fonction qui redemande une saisie tant qu\'elle est négative', () async {
      const source = '''
Fonction saisie_nb_positif( ) : entier
Variables nb_saisi : entier
Début
Saisir nb_saisi
Tant que nb_saisi < 0 Faire
Saisir nb_saisi
FinTQ
Retourner nb_saisi
Fin

Algorithme T
Variables n : entier
Début
n <- saisie_nb_positif()
Afficher n
Fin''';
      expect(await executer(source, ['-5', '7']), equals('7'));
    });

    test('un tableau rempli par une procédure, puis son mini et son maxi', () async {
      const source = '''
Procédure Saisietab (résultat untab(1 : 3) : tableau de réels)
Variables i : entier
Début
Pour i de 1 à 3 Faire
Saisir untab(i)
FinPour
Fin

Procédure minmax (donnée letab(1 : 3) : tableau de réels, résultats mini, maxi : réels)
Variables i : entier
Début
mini <- letab(1)
maxi <- letab(1)
Pour i de 2 à 3 Faire
Si letab(i) < mini
Alors mini <- letab(i)
Si letab(i) > maxi
Alors maxi <- letab(i)
FinPour
Fin

Algorithme notes
Variables tabnotes(1 : 3) : tableau de réels
notemin, notemax : réel
Début
Saisietab(tabnotes)
minmax(tabnotes, notemin, notemax)
Afficher notemax, " ", notemin
Fin''';
      expect(await executer(source, ['12', '5', '18']), equals('18.0 5.0'));
    });

    test('tri par échange, tableau en donnée-résultat', () async {
      const source = '''
Procédure tabtri(donnée-résultat letab(1 : 5) : tableau d'entiers)
Variables échange : booléen
i, dernier, temp : entier
Début
dernier <- 5
Répeter
échange <- faux
i <- 1
Tant que i < dernier Faire
Si letab(i) > letab(i + 1)
Alors
échange <- vrai
temp <- letab(i)
letab(i) <- letab(i + 1)
letab(i + 1) <- temp
FinSi
i <- i + 1
FinTQ
dernier <- dernier - 1
Jusqu'à non échange
Fin

Algorithme tri
Variables montab(1 : 5) : tableau d'entiers
i : entier
Début
Pour i de 1 à 5 Faire
Saisir montab(i)
FinPour
tabtri(montab)
Pour i de 1 à 5 Faire
Afficher montab(i), " "
FinPour
Fin''';
      expect(
        await executer(source, ['5', '3', '9', '1', '7']),
        equals('1 3 5 7 9 '),
      );
    });
  });
}
