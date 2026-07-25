/// Programmes d'exemple proposés dans le menu « Exemples ».
///
/// Extraits de `main_screen.dart` pour que l'écran ne porte plus 300 lignes de
/// données, et pour qu'ils deviennent testables : voir
/// `test/example_programs_test.dart`, qui vérifie qu'ils sont tous
/// syntaxiquement valides.
///
/// Les littéraux sont des chaînes BRUTES (`r"""..."""`) : sans cela, Dart
/// interpréterait les échappements et le `\n` destiné au programme SenAlgo
/// deviendrait un vrai saut de ligne dans l'éditeur.
library;

/// Un programme d'exemple affiché dans le menu.
class ExampleProgram {
  /// Libellé affiché dans le menu.
  final String title;

  /// Code SenAlgo chargé dans l'éditeur à la sélection.
  final String code;

  /// Si vrai, un séparateur est affiché avant cette entrée : les exemples
  /// sont regroupés par difficulté croissante.
  final bool startsGroup;

  const ExampleProgram({
    required this.title,
    required this.code,
    this.startsGroup = false,
  });
}

const List<ExampleProgram> kExamplePrograms = [
  ExampleProgram(
    title: "Table de multiplication",
    code: r"""ALGORITHME TableMultiplication
VARIABLES
  i, n: entier
DEBUT
  ecrire("Entrez un nombre : ")
  lire(n)
  POUR i ALLANT DE 1 à 10 FAIRE
    ecrire(n, " x ", i, " = ", n * i, "\n")
  FINPOUR
FIN""",
  ),
  ExampleProgram(
    title: "Factorielle",
    code: r"""ALGORITHME Factorielle
VARIABLES
  n, i, f: entier
DEBUT
  ecrire("Calcul de factorielle. Entrez n : ")
  lire(n)
  f <- 1
  POUR i ALLANT DE 1 à n FAIRE
    f <- f * i
  FINPOUR
  ecrire("La factorielle est : ", f, "\n")
FIN""",
  ),
  ExampleProgram(
    title: "Somme Simple",
    startsGroup: true,
    code: r"""ALGORITHME SommeSimple
VARIABLES
  a, b, s: entier
DEBUT
  ecrire("Entrez le premier nombre : ")
  lire(a)
  ecrire("Entrez le deuxième nombre : ")
  lire(b)
  s <- a + b
  ecrire("La somme est : ", s, "\n")
FIN""",
  ),
  ExampleProgram(
    title: "Parité d'un nombre",
    code: r"""ALGORITHME PariteNombre
VARIABLES
  n: entier
DEBUT
  ecrire("Entrez un nombre entier : ")
  lire(n)
  SI n mod 2 = 0 ALORS
    ecrire(n, " est PAIR\n")
  SINON
    ecrire(n, " est IMPAIR\n")
  FINSI
FIN""",
  ),
  ExampleProgram(
    title: "Infos Personne (Chaînes)",
    code: r"""ALGORITHME InfosPersonne
VARIABLES
  nom, prenom: chaîne
  age: entier
DEBUT
  ecrire("Quel est votre prénom ? ")
  lire(prenom)
  ecrire("Quel est votre nom ? ")
  lire(nom)
  ecrire("Quel est votre âge ? ")
  lire(age)
  ecrire("Bienvenue ", prenom, " ", nom, "\n")
  ecrire("Vous avez ", age, " ans.\n")
FIN""",
  ),
  ExampleProgram(
    title: "Calculatrice Simple",
    code: r"""ALGORITHME Calculatrice
VARIABLES
  x, y: réel
DEBUT
  ecrire("Entrez x : ")
  lire(x)
  ecrire("Entrez y : ")
  lire(y)
  ecrire("Somme : ", x + y, "\n")
  ecrire("Produit : ", x * y, "\n")
  SI y ≠ 0 ALORS
    ecrire("Division : ", x / y, "\n")
  SINON
    ecrire("Division impossible par zéro\n")
  FINSI
FIN""",
  ),
  ExampleProgram(
    title: "Triangle d'étoiles (Imbriqué)",
    startsGroup: true,
    code: r"""ALGORITHME TriangleEtoiles
VARIABLES
  i, j, n: entier
DEBUT
  ecrire("Taille du triangle : ")
  lire(n)
  POUR i ALLANT DE 1 à n FAIRE
    POUR j ALLANT DE 1 à i FAIRE
      ecrire("*")
    FINPOUR
    ecrire("\n")
  FINPOUR
FIN""",
  ),
  ExampleProgram(
    title: "Jeu : Devine le nombre (REPETER)",
    code: r"""ALGORITHME DevineNombre
VARIABLES
  secret, essai: entier
DEBUT
  secret <- 42  // On peut imaginer un hasard
  ecrire("--- JEU DU NOMBRE SECRET ---\n")
  REPETER
    ecrire("Devinez le nombre : ")
    lire(essai)
    SI essai < secret ALORS
      ecrire("C'est PLUS !\n")
    SINONSI essai > secret ALORS
      ecrire("C'est MOINS !\n")
    FINSI
  JUSQU'À essai = secret
  ecrire("BRAVO ! Vous avez trouvé.\n")
FIN""",
  ),
  ExampleProgram(
    title: "PGCD (TANTQUE)",
    code: r"""ALGORITHME CalculPGCD
VARIABLES
  a, b: entier
DEBUT
  ecrire("--- CALCUL DU PGCD (EUCLIDE) ---\n")
  ecrire("Entrez A : ")
  lire(a)
  ecrire("Entrez B : ")
  lire(b)
  TANTQUE a ≠ b FAIRE
    SI a > b ALORS
      a <- a - b
    SINON
      b <- b - a
    FINSI
  FINTANTQUE
  ecrire("Le PGCD est : ", a, "\n")
FIN""",
  ),
  ExampleProgram(
    title: "Somme chiffres (TANTQUE)",
    code: r"""ALGORITHME SommeChiffres
VARIABLES
  n, s, reste: entier
DEBUT
  ecrire("Entrez un nombre : ")
  lire(n)
  s <- 0
  TANTQUE n ≠ 0 FAIRE
    reste <- n mod 10
    s <- s + reste
    n <- n div 10
  FINTANTQUE
  ecrire("La somme des chiffres est : ", s, "\n")
FIN""",
  ),
  ExampleProgram(
    title: "Tri à Bulle (Tableaux)",
    code: r"""ALGORITHME TriABulle
VARIABLES
  i, j, temp : entier
  t : TABLEAU [1..5] DE ENTIER
DEBUT
  ecrire "--- Saisie du tableau ---\\n"
  POUR i DE 1 à 5 FAIRE
    ecrire "Entrez l'élément ", i, " : "
    lire t[i]
  FINPOUR

  // Tri à bulle
  POUR i DE 1 à 4 FAIRE
    POUR j DE 1 à 5 - i FAIRE
      SI t[j] > t[j+1] ALORS
        temp <- t[j]
        t[j] <- t[j+1]
        t[j+1] <- temp
      FINSI
    FINPOUR
  FINPOUR

  ecrire "\\nTableau trié : "
  POUR i DE 1 à 5 FAIRE
    ecrire t[i], " "
  FINPOUR
  ecrire "\\n"
FIN""",
  ),
  ExampleProgram(
    title: "Taux selon montant ",
    startsGroup: true,
    code: r"""ALGORITHME TauxSelonMontant
VARIABLES
  montant, taux : entier
DEBUT
  Ecrire "Entrez le montant : "
  Lire montant
  Selon montant Faire
    < 1000 : taux <- 10
    ≥ 1000 et < 3000 : taux <- 20
    ≥ 3000 et < 10000 : taux <- 30
    ≥ 10000 : taux <- 40
  FinSelon
  Afficher "Taux appliqué : ", taux, "%\\n"
FIN""",
  ),
  ExampleProgram(
    title: "Mois en lettres (SELON valeurs)",
    code: r"""ALGORITHME MoisEnLettres
VARIABLES
  mois : entier
DEBUT
  Ecrire "Entrez un numéro de mois (1-12) : "
  Lire mois
  Selon mois Faire
    1 : Afficher "Janvier"
    2 : Afficher "Février"
    3 : Afficher "Mars"
    4 : Afficher "Avril"
    5 : Afficher "Mai"
    6 : Afficher "Juin"
    7 : Afficher "Juillet"
    8 : Afficher "Août"
    9 : Afficher "Septembre"
    10 : Afficher "Octobre"
    11 : Afficher "Novembre"
    12 : Afficher "Décembre"
    Sinon Afficher "Un numéro de mois doit être compris entre 1 et 12"
  FinSelon
FIN""",
  ),
  ExampleProgram(
    title: "Procédure donnée-résultat (passage par référence)",
    code: r"""ALGORITHME EchangeEtSomme
Procédure Echanger (donnée-résultat a : entier, donnée-résultat b : entier)
Variables
  temp : entier
Début
  temp <- a
  a <- b
  b <- temp
Fin

Fonction Cube (donnée nombre : entier) : entier
Début
  Retourner nombre * nombre * nombre
Fin

VARIABLES
  x, y : entier
DEBUT
  x <- 5
  y <- 12
  Ecrire "Avant échange : x=", x, " y=", y, "\\n"
  Echanger(x, y)
  Ecrire "Après échange : x=", x, " y=", y, "\\n"
  Ecrire "Cube de x : ", Cube(x), "\\n"
FIN""",
  ),
  ExampleProgram(
    title: "Compteur (Tant que … Faire)",
    code: r"""ALGORITHME CompteurTantQue
VARIABLES
  n : entier
DEBUT
  n <- 1
  Tant que n <= 5 Faire
    Afficher "n = ", n, "\\n"
    n <- n + 1
  FinTant que
FIN""",
  ),
];
