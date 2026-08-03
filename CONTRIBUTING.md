# Contribuer à SenAlgo

Merci de vouloir aider. Ce fichier tient en une page : ce sont les quelques
règles qui évitent les allers-retours, pas un règlement.

## La version de Flutter

Le projet est développé et construit avec **Flutter 3.41.9** (Dart SDK
`^3.10.1`). La CI et les builds de release sont épinglés sur cette version.

Ça compte plus qu'il n'y paraît. Un Flutter plus récent réécrit
`pubspec.lock` avec des contraintes que 3.41.9 ne sait pas satisfaire, et
tire des dépendances qui n'ont rien à voir avec ce que tu ajoutes.

```bash
flutter --version    # doit afficher 3.41.9
```

## Les fichiers à ne pas committer

Ces fichiers sont produits par les outils, pas écrits à la main. Ils
changent tout seuls dès que tu lances `flutter pub get` ou `flutter run`,
et ils n'ont rien à faire dans une PR de fonctionnalité :

- `pubspec.lock`
- `.metadata`
- `linux/flutter/generated_plugins.cmake` et son équivalent Windows

Si tu les vois dans ton `git status` alors que tu ne les as pas touchés :

```bash
git checkout main -- pubspec.lock .metadata
```

Une mise à jour de dépendances est légitime, mais elle mérite sa propre PR :
si quelque chose casse, on veut savoir si c'est la fonctionnalité ou la
dépendance. à ne pas negliger la

## Avant de pousser

```bash
flutter analyze     # doit afficher « No issues found! »
flutter test        # tout doit passer
```

La CI lance exactement ces deux commandes. Autant le savoir avant.

## Une fonctionnalité vient avec son test

Même court. Le but n'est pas la couverture, c'est que le prochain qui
touchera ton code sache tout de suite s'il l'a cassé.

Un bon test vérifie **l'effet**, pas le passage dans le code.

Voir `test/` pour des exemple complets, canal système
simulé compris.

## Les messages de commit

Un message dit ce que le commit fait, au présent, en une ligne courte.
S'il commence par « corrige », il doit corriger quelque chose : une
réécriture à comportement identique n'est pas un correctif. Un historique
où « fix » ne corrige rien ne sert plus à rien le jour où on cherche quand
un bug est apparu.

Pas de `Co-Authored-By`les IA là haha 

## Le texte affiché à l'utilisateur

Tout ce que l'utilisateur lit est **en français**, y compris les erreurs.
Personne n'apprend l'algorithmique en déchiffrant un message d'exception
Dart.

- Accorde le pluriel : `'$n ligne${n > 1 ? "s" : ""} copiée${n > 1 ? "s" : ""}'`
- Cite la ligne concernée quand il s'agit d'une erreur du programme

## Riverpod

`ref.watch` ne s'appelle **que** pendant `build`. Partout ailleurs, dans un
`onPressed`, un `initState`, une méthode appelée par un clic, c'est
`ref.read`. Sinon on inscrit une dépendance là où on voulait juste lire une
valeur.

## Les commentaires

Un commentaire explique **pourquoi**, pas quoi. Le code dit déjà ce qu'il
fait.

Il s'adresse à quelqu'un qui lit le fichier dans six mois sans rien savoir
du contexte : pas de référence à « la dernière exécution », à un ticket, ou
à une conversation. Si le pourquoi tient dans une phrase, une phrase suffit.

## L'architecture, en deux lignes

`lib/core/` est le langage et ne dépend d'aucune interface. `lib/ui/` et
`lib/state/` en dépendent, jamais l'inverse. Une règle du langage se corrige
dans `core/`, jamais dans un widget.


