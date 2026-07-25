import 'package:flutter/material.dart';
import '../ui/theme.dart';

class SenAlgoMode {
  static const Map<String, dynamic> senalgo = {
    'keywords': {
      'keyword': 'algorithme constante type variable variables var debut début fin si alors sinon sinonsi finsi pour allant de à pas finpour tantque tant que fintant fintantque faire repeter répéter jusqua jusqu\'à cas selon fincas finselon fonction procedure procédure retourner structure autre vaut dans donnee donnée resultat résultat et ou non div mod entier reel réel booleen booléen caractere caractère chaine chaîne tableau',
      'literal': 'vrai faux',
      'built_in': 'ecrire écrire ecrireln écrireln afficher afficherln lire saisir abs racine sqrt entier'
    },
    'contains': [
      {'className': 'string', 'begin': '"', 'end': '"'},
      {'className': 'string', 'begin': "'", 'end': "'"},
      {'className': 'comment', 'begin': '//', 'end': '\$'},
      {'className': 'comment', 'begin': '{', 'end': '}'},
      {'className': 'number', 'begin': '\\b\\d+(\\.\\d+)?\\b'},
      {'className': 'operator', 'begin': '<-|:=|=|<|>|≠|≥|≤|\\+|-|\\*|/|\\.\\.'},
    ]
  };
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
