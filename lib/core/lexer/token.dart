// ignore_for_file: constant_identifier_names

enum TokenType {
  ALGORITHME, CONSTANTE, TYPE, VAR, DEBUT, FIN, SI, ALORS, SINON, SINONSI, FINSI, POUR, A, ALLANT, PAS, FINPOUR, TANTQUE, FAIRE, FINTANTQUE, REPETER, JUSQUA, CAS, FINCAS, SELON, FONCTION, PROCEDURE, RETOURNER, STRUCTURE, AUTRE, VAUT, DANS, DONNEE, RESULTAT,
  ECRIRE, AFFICHER, LIRE, SAISIR, ECRIRELN, AFFICHERLN,
  T_ENTIER, T_REEL, T_BOOLEEN, T_CARACTERE, T_CHAINE, T_TABLEAU,
  IDENTIFIANT, ENTIER, REEL, CHAINE, BOOLEEN,
  PLUS, MOINS, FOIS, DIVISE, DIV, MOD, AFFECTATION, EGAL, DIFFERENT, PLUS_PETIT, PLUS_PETIT_EGAL, PLUS_GRAND, PLUS_GRAND_EGAL, ET, OU, NON,
  PAREN_OUVRANTE, PAREN_FERMANTE, CROCHET_OUVRANT, CROCHET_FERMANT, ACCOLADE_OUVRANTE, ACCOLADE_FERMANTE, VIRGULE, DEUX_POINTS, POINT_VIRGULE, POINT, POINT_POINT,
  EOF, ERREUR
}

class Token {
  final TokenType type;
  final String lexeme;
  final dynamic literal;
  final int line;
  final int column;
  Token({required this.type, required this.lexeme, this.literal, required this.line, required this.column});
  @override
  String toString() => 'Token($type, "$lexeme", $literal, $line:$column)';
}
