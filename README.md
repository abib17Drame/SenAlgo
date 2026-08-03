# SenAlgo

[![CI](https://github.com/abib17Drame/SenAlgo/actions/workflows/ci.yml/badge.svg)](https://github.com/abib17Drame/SenAlgo/actions/workflows/ci.yml)

Un environnement de développement pour l'**algorithmique en pseudocode français**

Écrire un algorithme sur une feuille ne dit pas s'il est juste. SenAlgo permet de le **taper**, de l'**exécuter**, de le **dérouler pas à pas** en regardant les variables changer, puis de le **traduire en Python** pour faire le pont avec un vrai langage de programmation.

```
ALGORITHME MonAlgo
VARIABLES
  a, b, s: entier
DEBUT
  a <- 5
  b <- 10
  s <- a + b
  ecrire("La somme de ", a, " et ", b, " est ", s, "\n")
FIN
```

## Fonctionnalités

- **Éditeur** avec coloration syntaxique, autocomplétion (mots-clés du langage **et** noms que tu déclares), indentation automatique des blocs et retour à la ligne activable.
- **Diagnostics en direct** : les erreurs de syntaxe sont signalées pendant la frappe, avec le numéro de ligne, sans avoir à lancer le programme.
- **Vérification des types**, à deux niveaux : ce qui est certainement faux (`n : entier` recevant une chaîne, un `SI` dont la condition n'est pas booléenne) **empêche le programme de démarrer** ; ce qui est douteux mais défendable se contente d'un avertissement. Le type déclaré est ensuite tenu à l'exécution, et toutes les erreurs s'affichent en français avec leur ligne.
- **Exécution** avec console interactive (`Lire` attend une saisie), interruptible à tout moment : une boucle infinie s'arrête d'un clic sur **Arrêter**. La sortie se copie dans le presse-papier d'un clic.
- **Débogueur pas à pas** : une instruction à la fois, ligne courante surlignée, explication de ce qui se passe, et panneau des variables mis à jour en direct. Mode automatique disponible.
- **Traduction en Python**, pour transposer un algorithme connu vers un langage réel.
- **15 exemples** prêts à charger, du plus simple au tri à bulle.
- **Ouverture et sauvegarde** de fichiers `.algo`, et **reprise automatique** : le programme en cours est retrouvé au lancement suivant, même après une fermeture brutale.

## Installation

Il faut [Flutter](https://docs.flutter.dev/get-started/install) (développé avec la 3.41.9, Dart SDK `^3.10.1`).

```bash
git clone <url-du-depot>
cd SenAlgo
flutter pub get
flutter run          # ou : flutter run -d linux / -d chrome
```

Plateformes configurées : **Linux**, **Android** et **Web**.

## Le langage

SenAlgo est volontairement **tolérant sur l'écriture** : accents facultatifs, casse indifférente, pluriels acceptés, et plusieurs notations pour un même symbole. L'idée est que ce que tu recopies de ton polycopié fonctionne.

### Structure d'un programme

```
ALGORITHME NomDeLAlgorithme
CONSTANTES
  PI = 3.14
VARIABLES
  x, y : entier
  nom : chaine
DEBUT
  ...
FIN
```

### Types

`entier` · `réel` · `booléen` · `caractère` · `chaîne` · `tableau`

Les variantes sans accent et au pluriel sont acceptées (`reel`, `booleens`, `chaines`…).

Un **caractère** s'écrit entre apostrophes et n'en contient qu'un seul, une **chaîne** entre guillemets doubles et en contient autant qu'on veut :

```
rep <- 'o'
nom <- "moussa"
```

Ce sont les guillemets qui décident du type, pas la longueur du texte. `c <- "o"` met une chaîne dans un caractère : ça tient, donc le programme tourne, mais un avertissement rappelle la bonne notation. L'inverse, `nom <- 'o'`, ne dit rien : un caractère est une chaîne d'une lettre, il n'y a rien à perdre.

Les caractères se comparent dans l'ordre ASCII, donc `'Z' < 'a'` est vrai.

### Instructions

| Construction | Écriture |
|---|---|
| Affectation | `x <- 5` (aussi `←`, `:=`, `->`) |
| Condition | `SI … ALORS … SINONSI … ALORS … SINON … FINSI` |
| Boucle bornée | `POUR i ALLANT DE 1 à 10 [PAS 2] FAIRE … FINPOUR` |
| Boucle conditionnelle | `TANT QUE … FAIRE … FINTANTQUE` |
| Boucle à sortie | `REPETER … JUSQU'À …` (aussi `JUSQUA`, sans apostrophe ni accent) |
| Sélection | `SELON expr FAIRE … FINSELON` |
| Affichage | `ecrire(…)`, `ecrireln(…)`, `afficher(…)` |
| Saisie | `lire(x)`, `saisir(x)` |

`Tant que` et `FinTant que` s'écrivent indifféremment en un ou deux mots.

`SELON` accepte à la fois des valeurs et des comparaisons enchaînées :

```
Selon montant Faire
  < 1000 : taux <- 10
  ≥ 1000 et < 3000 : taux <- 20
  Sinon taux <- 40
FinSelon
```

### Tableaux

```
VARIABLES
  t : TABLEAU[1..10] DE entier    { ou :  t(1:10) : tableau de entier }
DEBUT
  t[1] <- 42                       { ou :  t(1) <- 42 }
```

Les bornes sont libres : `TABLEAU[5..20]` est valide, l'indexation reste celle que tu as déclarée.

### Fonctions et procédures

Les trois statuts de paramètres sont implémentés : `donnée` (entrée, par défaut), `résultat` (sortie), `donnée-résultat` (entrée-sortie, passage par référence).

```
PROCEDURE Echanger(donnée-résultat a : entier, donnée-résultat b : entier)
VARIABLES tmp : entier
DEBUT
  tmp <- a
  a <- b
  b <- tmp
FIN

FONCTION Carre(n : entier) : entier
DEBUT
  RETOURNER n * n
FIN
```

### Opérateurs

- Arithmétiques : `+` `-` `*` `/` `DIV` (division entière) `MOD` (reste) `^` (puissance, ou `**`)
- Comparaison : `=` `≠` (ou `<>`, `!=`) `<` `≤` (ou `<=`) `>` `≥` (ou `>=`), sur les nombres, les caractères et les chaînes
- Logiques : `ET` `OU` `NON`

### Fonctions intégrées

`abs(x)` · `racine(x)` (alias `sqrt`) · `entier(x)`

### Commentaires

```
// commentaire sur une ligne
{ commentaire pouvant tenir sur plusieurs lignes }
```

## Architecture

```
lib/
  core/                    le langage, sans aucune dépendance à l'interface
    lexer/                 texte  ->  jetons
    parser/                jetons ->  arbre syntaxique
    ast/                   noeuds de l'arbre + visiteur
    interpreter/           exécution de l'arbre
    transpiler/            génération de code Python
  state/                   état de l'application (Riverpod)
  ui/
    screens/               écran principal
    widgets/               panneaux et composants réutilisables
    editor/                éditeur de code et indentation
    dialogs/               boîtes de dialogue
    examples/              programmes d'exemple
    services/              lecture/écriture de fichiers
```

L'interpréteur et le transpileur implémentent le **même visiteur** sur l'arbre syntaxique : ajouter un langage cible ne demande pas de toucher au reste.

## Tests

```bash
flutter test        # 242 tests
flutter analyze     # doit rester à « No issues found! »
```

La couverture porte sur l'analyse lexicale, l'analyse syntaxique, l'analyse sémantique, l'exécution, la traduction Python, la validité de chacun des 15 exemples, et l'absence de débordement d'affichage sur six tailles d'écran allant de 320×568 à 1920×1080.

Trois familles de tests méritent d'être signalées :

- **Traduction Python vérifiée par exécution.** Chaque programme est exécuté par l'interpréteur SenAlgo *et* par `python3` ; les deux sorties doivent coïncider au caractère près. Une traduction plausible mais fausse ne peut donc pas passer.
- **Absence de faux positifs.** Les 15 exemples doivent produire zéro avertissement sémantique. Un analyseur qui crie au loup sur du code correct est pire qu'une absence d'analyse : il apprend à ignorer les avertissements, et depuis que les erreurs bloquent l'exécution, un seul faux positif empêcherait carrément de travailler.
- **Le refus d'exécuter est vérifié par son effet.** Le programme fautif du test affiche quelque chose *avant* la ligne en faute : si le blocage cessait de fonctionner, cet affichage apparaîtrait. Un test qui se contenterait de chercher le message « Exécution refusée » passerait encore.

## Limites connues

- **Types personnalisés non implémentés.** `Type`, `Structure` et `Enregistrement` sont reconnus par l'analyseur lexical mais lèvent une erreur explicite plutôt que d'être ignorés en silence.
- **Variables non initialisées.** Lire une variable à laquelle rien n'a encore été affecté donne la valeur par défaut de son type (`0`, `""`, `faux`) sans rien signaler.
- **`REPETER … JUSQU'À`** est la seule construction dont la condition ne peut pas commencer par un opérateur sur une nouvelle ligne : aucun mot-clé ne la ferme, donc rien n'indiquerait où elle s'arrête. Les parenthèses lèvent la restriction.
- **Traduction Python** : un tableau dont la borne inférieure ne peut pas être déterminée à la déclaration (paramètre sans bornes explicites) est supposé indexé à partir de 0.
