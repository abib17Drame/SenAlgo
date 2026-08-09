import 'package:flutter/material.dart';
import 'package:highlight/highlight_core.dart';
import '../ui/theme.dart';

class SenAlgoMode {
  static const Map<String, String> motsCles = {
    'keyword': 'algorithme constante type variable variables var debut début fin si alors sinon sinonsi finsi pour allant de à pas finpour tantque tant que fintant fintantque faire repeter répéter jusqua jusquà jusqu\'a jusqu\'à cas selon fincas finselon fonction procedure procédure retourner structure autre vaut dans donnee donnée resultat résultat et ou non div mod entier reel réel booleen booléen caractere caractère chaine chaîne tableau',
    'literal': 'vrai faux',
    'built_in': 'ecrire écrire ecrireln écrireln afficher afficherln lire saisir abs racine sqrt entier'
  };

  /// Découpe un mot comme le lexeur : accents et apostrophe compris.
  /// Le défaut de `highlight` est `\w+`, qui coupe `JUSQU'À` et `répéter`.
  static const decoupageDesMots = r"[A-Za-zÀ-ÿ0-9_']+";

  /// Un caractère complet : une lettre ou un échappement, entre apostrophes.
  /// Le motif entier est exigé, sinon l'apostrophe de `JUSQU'À` ouvrirait
  /// un caractère qui colorierait tout le reste du programme.
  static const caractere = r"'(\\.|[^'\\\n])'";

  /// La grammaire de coloration reçue par l'éditeur.
  static Mode get grammaire => Mode(
        case_insensitive: true,
        refs: {},
        keywords: motsCles,
        lexemes: decoupageDesMots,
        contains: [
          Mode(className: 'string', begin: '"', end: '"'),
          Mode(className: 'string', begin: caractere),
          Mode(className: 'comment', begin: '//', end: '\$'),
          Mode(className: 'comment', begin: '{', end: '}'),
          Mode(className: 'number', begin: r'\b\d+(\.\d+)?\b'),
          Mode(
            className: 'operator',
            begin: r'<-|:=|<=|>=|<>|!=|≠|≥|≤|\*\*|=|<|>|\+|-|\*|\^|/|\.\.',
          ),
        ],
      );
}

class SenAlgoSyntaxColors {
  static final Map<String, TextStyle> styles = {
    'keyword': const TextStyle(color: SenAlgoTheme.neonGreen, fontWeight: FontWeight.bold),
    'literal': const TextStyle(color: SenAlgoTheme.neonPink),
    'built_in': const TextStyle(color: SenAlgoTheme.neonYellow),
    'string': const TextStyle(color: Colors.orangeAccent),
    'comment': const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
    'number': const TextStyle(color: SenAlgoTheme.neonCyan),
    'operator': const TextStyle(color: SenAlgoTheme.neonPink),
  };
}
