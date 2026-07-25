import 'token.dart';

class Lexer {
  final String source;
  final List<Token> tokens = [];
  int _start = 0;
  int _current = 0;
  int _line = 1;
  int _column = 0;

  static const Map<String, TokenType> _keywords = {
    'algorithme': TokenType.ALGORITHME, 'constante': TokenType.CONSTANTE, 'constantes': TokenType.CONSTANTE, 'const': TokenType.CONSTANTE, 'type': TokenType.TYPE, 'variable': TokenType.VAR, 'variables': TokenType.VAR, 'var': TokenType.VAR, 'debut': TokenType.DEBUT, 'début': TokenType.DEBUT, 'fin': TokenType.FIN, 'si': TokenType.SI, 'alors': TokenType.ALORS, 'sinon': TokenType.SINON, 'sinonsi': TokenType.SINONSI, 'finsi': TokenType.FINSI, 'fsi': TokenType.FINSI, 'pour': TokenType.POUR, 'allant': TokenType.ALLANT, 'de': TokenType.DANS, 'à': TokenType.A, 'À': TokenType.A, 'pas': TokenType.PAS, 'finpour': TokenType.FINPOUR, 'fpour': TokenType.FINPOUR, 'tantque': TokenType.TANTQUE, 'faire': TokenType.FAIRE, 'fintantque': TokenType.FINTANTQUE, 'ftantque': TokenType.FINTANTQUE,    'repeter': TokenType.REPETER, 'répéter': TokenType.REPETER, 'jusqua': TokenType.JUSQUA, 'jusqu\'à': TokenType.JUSQUA, 'cas': TokenType.CAS, 'selon': TokenType.SELON, 'fincas': TokenType.FINCAS, 'fcas': TokenType.FINCAS, 'finselon': TokenType.FINCAS, 'fselon': TokenType.FINCAS, 'fonction': TokenType.FONCTION, 'procedure': TokenType.PROCEDURE, 'procédure': TokenType.PROCEDURE, 'retourner': TokenType.RETOURNER, 'retourne': TokenType.RETOURNER, 'structure': TokenType.STRUCTURE, 'struct': TokenType.STRUCTURE, 'enregistrement': TokenType.STRUCTURE, 'autre': TokenType.AUTRE, 'autres': TokenType.AUTRE, 'vaut': TokenType.VAUT, 'dans': TokenType.DANS, 'et': TokenType.ET, 'ou': TokenType.OU, 'non': TokenType.NON, 'div': TokenType.DIV, 'mod': TokenType.MOD, 'entier': TokenType.T_ENTIER, 'entiers': TokenType.T_ENTIER, 'reel': TokenType.T_REEL, 'réel': TokenType.T_REEL, 'reels': TokenType.T_REEL, 'réels': TokenType.T_REEL, 'booleen': TokenType.T_BOOLEEN, 'booléen': TokenType.T_BOOLEEN, 'booleens': TokenType.T_BOOLEEN, 'booléens': TokenType.T_BOOLEEN, 'caractere': TokenType.T_CARACTERE, 'caractère': TokenType.T_CARACTERE, 'caracteres': TokenType.T_CARACTERE, 'caractères': TokenType.T_CARACTERE, 'chaine': TokenType.T_CHAINE, 'chaîne': TokenType.T_CHAINE, 'tableau': TokenType.T_TABLEAU, 'vrai': TokenType.BOOLEEN, 'faux': TokenType.BOOLEEN,
    'ecrire': TokenType.ECRIRE, 'écrire': TokenType.ECRIRE, 'afficher': TokenType.AFFICHER, 'lire': TokenType.LIRE, 'saisir': TokenType.SAISIR, 'ecrireln': TokenType.ECRIRELN, 'écrireln': TokenType.ECRIRELN, 'afficherln': TokenType.AFFICHERLN,
    // Statut des paramètres : donnée, résultat, donnée-résultat
    'donnee': TokenType.DONNEE, 'donnée': TokenType.DONNEE, 'resultat': TokenType.RESULTAT, 'résultat': TokenType.RESULTAT,
  };

  Lexer(this.source);

  /// Indique si [mot] est un mot réservé du langage et ne peut donc pas servir
  /// de nom de variable, de fonction ou d'algorithme. Permet au parseur de
  /// donner un message clair plutôt qu'un « nom attendu » sans explication.
  static bool isReservedWord(String mot) => _keywords.containsKey(mot.toLowerCase());

  List<Token> scanTokens() {
    while (!_isAtEnd()) {
      _start = _current;
      _scanToken();
    }
    tokens.add(Token(type: TokenType.EOF, lexeme: '', line: _line, column: _column));
    return tokens;
  }

  bool _isAtEnd() => _current >= source.length;

  void _scanToken() {
    final c = _advance();
    switch (c) {
      case '(': _addSimpleToken(TokenType.PAREN_OUVRANTE); break;
      case ')': _addSimpleToken(TokenType.PAREN_FERMANTE); break;
      case '[': _addSimpleToken(TokenType.CROCHET_OUVRANT); break;
      case ']': _addSimpleToken(TokenType.CROCHET_FERMANT); break;
      case ',': _addSimpleToken(TokenType.VIRGULE); break;
      case ';': _addSimpleToken(TokenType.POINT_VIRGULE); break;
      case '+': _addSimpleToken(TokenType.PLUS); break;
      case '*': _addSimpleToken(TokenType.FOIS); break;
      case '=': _addSimpleToken(TokenType.EGAL); break;
      case '←': _addSimpleToken(TokenType.AFFECTATION); break;
      case '≠': _addSimpleToken(TokenType.DIFFERENT); break;
      case '≥': _addSimpleToken(TokenType.PLUS_GRAND_EGAL); break;
      case '≤': _addSimpleToken(TokenType.PLUS_PETIT_EGAL); break;
      case '.':
        if (_match('.')) { _addSimpleToken(TokenType.POINT_POINT); } else { _addSimpleToken(TokenType.POINT); }
        break;
      case ':':
        if (_match('=')) { _addSimpleToken(TokenType.AFFECTATION); } else { _addSimpleToken(TokenType.DEUX_POINTS); }
        break;
      case '-':
        if (_match('>')) { _addSimpleToken(TokenType.AFFECTATION); } else { _addSimpleToken(TokenType.MOINS); }
        break;
      case '<':
        if (_match('-')) {
          _addSimpleToken(TokenType.AFFECTATION);
        } else if (_match('=')) {
          _addSimpleToken(TokenType.PLUS_PETIT_EGAL);
        } else if (_match('>')) {
          _addSimpleToken(TokenType.DIFFERENT);
        } else {
          _addSimpleToken(TokenType.PLUS_PETIT);
        }
        break;
      case '>':
        if (_match('=')) {
          _addSimpleToken(TokenType.PLUS_GRAND_EGAL);
        } else {
          _addSimpleToken(TokenType.PLUS_GRAND);
        }
        break;
      case '/':
        if (_match('/')) {
          while (_peek() != '\n' && !_isAtEnd()) {
            _advance();
          }
        } else {
          _addSimpleToken(TokenType.DIVISE);
        }
        break;
      case '{':
        while (_peek() != '}' && !_isAtEnd()) {
          if (_peek() == '\n') {
            _line++;
            _column = 0;
          }
          _advance();
        }
        if (!_isAtEnd()) _advance();
        break;
      case ' ': case '\r': case '\t': case '\u00A0': break;
      case '\n': _line++; _column = 0; break;
      case '"': _string('"'); break;
      case "'": _string("'"); break;
      case '!':
        if (_match('=')) { _addSimpleToken(TokenType.DIFFERENT); }
        else { _addToken(TokenType.ERREUR, 'Caractère inattendu: !'); }
        break;
      default:
        if (_isDigit(c)) {
          _number();
        } else if (_isAlpha(c)) {
          _identifier();
        } else {
          _addToken(TokenType.ERREUR, 'Caractère inattendu: $c');
        }
        break;
    }
  }

  void _identifier() {
    while (_isAlphaNumeric(_peek())) {
      _advance();
    }
    final text = source.substring(_start, _current);
    final lower = text.toLowerCase();

    // Mots-clés en plusieurs mots : "Tant que" / "FinTant que".
    // On accepte aussi les variantes historiques en un seul mot ("tantque",
    // "fintantque") qui restent gérées par la table `_keywords` ci-dessus.
    if (lower == 'tant') {
      if (_tryConsumeWord('que')) {
        _addToken(TokenType.TANTQUE);
        return;
      }
    } else if (lower == 'fin') {
      final savedCurrent = _current;
      final savedColumn = _column;
      if (_tryConsumeWord('tant') && _tryConsumeWord('que')) {
        _addToken(TokenType.FINTANTQUE);
        return;
      }
      // Pas "Fin Tant que" : on revient juste après "fin" et on traite
      // "fin" normalement (mot-clé FIN de fin de programme/bloc).
      _current = savedCurrent;
      _column = savedColumn;
    } else if (lower == 'fintant') {
      if (_tryConsumeWord('que')) {
        _addToken(TokenType.FINTANTQUE);
        return;
      }
    }

    var type = _keywords[lower];
    if (type == TokenType.BOOLEEN) {
      _addToken(type!, lower == 'vrai');
    } else {
      _addToken(type ?? TokenType.IDENTIFIANT);
    }
  }

  /// Si le mot suivant (en ignorant les espaces/tabulations, mais pas les
  /// retours à la ligne) correspond exactement à [word] (insensible à la
  /// casse) et n'est pas suivi d'autres caractères alphanumériques, avance
  /// le curseur au-delà de ce mot et renvoie true. Sinon, ne bouge pas le
  /// curseur et renvoie false.
  bool _tryConsumeWord(String word) {
    int i = _current;
    while (i < source.length && (source[i] == ' ' || source[i] == '\t' || source[i] == '\u00A0')) {
      i++;
    }
    final start = i;
    int j = start;
    while (j < source.length && _isAlphaNumeric(source[j])) {
      j++;
    }
    final candidate = source.substring(start, j);
    if (candidate.toLowerCase() != word) return false;
    _column += (j - _current);
    _current = j;
    return true;
  }

  void _number() {
    while (_isDigit(_peek())) {
      _advance();
    }
    if (_peek() == '.' && _isDigit(_peekNext())) {
      _advance();
      while (_isDigit(_peek())) {
        _advance();
      }
      _addToken(TokenType.REEL, double.parse(source.substring(_start, _current)));
    } else {
      _addToken(TokenType.ENTIER, int.parse(source.substring(_start, _current)));
    }
  }

  void _string(String quote) {
    StringBuffer buffer = StringBuffer();
    while (_peek() != quote && !_isAtEnd()) {
      if (_peek() == '\n') {
        _line++;
        _column = 0;
      }
      
      if (_peek() == '\\') {
        _advance(); // Skip \
        if (_isAtEnd()) break;
        final escaped = _advance();
        switch (escaped) {
          case 'n': buffer.write('\n'); break;
          case 't': buffer.write('\t'); break;
          case 'r': buffer.write('\r'); break;
          case '\\': buffer.write('\\'); break;
          case '"': buffer.write('"'); break;
          case "'": buffer.write("'"); break;
          default: buffer.write('\\$escaped'); break;
        }
      } else {
        buffer.write(_advance());
      }
    }
    
    if (_isAtEnd()) { _addToken(TokenType.ERREUR, 'Chaîne non terminée'); return; }
    _advance(); // The closing quote
    _addToken(TokenType.CHAINE, buffer.toString());
  }

  bool _match(String expected) {
    if (_isAtEnd() || source[_current] != expected) return false;
    _current++; _column++; return true;
  }

  String _peek() => _isAtEnd() ? '\x00' : source[_current];
  String _peekNext() => _current + 1 >= source.length ? '\x00' : source[_current + 1];
  String _advance() { _column++; return source[_current++]; }
  bool _isDigit(String c) { if (c == '\x00') return false; final code = c.codeUnitAt(0); return code >= 48 && code <= 57; }
  bool _isAlpha(String c) { if (c == '\x00') return false; final code = c.codeUnitAt(0); return (code >= 65 && code <= 90) || (code >= 97 && code <= 122) || code == 95 || code == 39 || (code >= 192 && code <= 255); }
  bool _isAlphaNumeric(String c) => _isAlpha(c) || _isDigit(c);
  void _addSimpleToken(TokenType type) => _addToken(type);
  void _addToken(TokenType type, [dynamic literal]) {
    final text = source.substring(_start, _current);
    tokens.add(Token(type: type, lexeme: text, literal: literal, line: _line, column: _column - (text.length)));
  }
}
