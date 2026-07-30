import '../lexer/token.dart';
import '../lexer/lexer.dart';
import '../ast/ast.dart';

class Parser {
  final List<Token> tokens;
  int _current = 0;

  Parser(this.tokens);

  ProgramNode parse() {
    String name = "";
    if (_match(TokenType.ALGORITHME)) { name = _consumeIdentifier("d'algorithme").lexeme; }
    final List<ASTNode> declarations = [];
    while (!_check(TokenType.DEBUT) && !_isAtEnd()) {
      if (_match(TokenType.VAR)) { declarations.addAll(_varDeclarations()); }
      else if (_match(TokenType.CONSTANTE)) { declarations.addAll(_constDeclarations()); }
      else if (_match(TokenType.FONCTION)) { declarations.add(_functionDeclaration()); }
      else if (_match(TokenType.PROCEDURE)) { declarations.add(_procedureDeclaration()); }
      else if (_check(TokenType.STRUCTURE) || _check(TokenType.TYPE)) { _throwNotImplemented(); }
      else { _advance(); }
    }
    _consume(TokenType.DEBUT, "DEBUT attendu.");
    final body = _block(TokenType.FIN);
    _consume(TokenType.FIN, "FIN attendu.");
    return ProgramNode(name: name, declarations: declarations, body: body);
  }

  List<ASTNode> _varDeclarations() {
    final List<ASTNode> decls = [];
    while (_check(TokenType.IDENTIFIANT)) {
      final List<String> ids = [];
      final firstToken = _consumeIdentifier("de variable");
      ids.add(firstToken.lexeme);
      
      // Check for 'id(low : high)' style declaration
      if (_match(TokenType.PAREN_OUVRANTE)) {
        final lower = _expression();
        _consume(TokenType.DEUX_POINTS, ": attendu.");
        final upper = _expression();
        _consume(TokenType.PAREN_FERMANTE, ") attendue.");
        _consume(TokenType.DEUX_POINTS, ": attendu.");
        _consume(TokenType.T_TABLEAU, "TABLEAU attendu.");
        _match(TokenType.DANS); // optional 'de'
        final baseType = _advance().lexeme;
        decls.add(ArrayDeclarationNode(identifiers: ids, lowerBound: lower, upperBound: upper, baseType: baseType));
        continue;
      }

      while (_match(TokenType.VIRGULE)) { ids.add(_consumeIdentifier("de variable").lexeme); }
      _consume(TokenType.DEUX_POINTS, ": attendu.");
      
      if (_match(TokenType.T_TABLEAU)) {
        _consume(TokenType.CROCHET_OUVRANT, "[ attendu après TABLEAU.");
        final lower = _expression();
        _consume(TokenType.POINT_POINT, ".. attendu.");
        final upper = _expression();
        _consume(TokenType.CROCHET_FERMANT, "] attendu.");
        _match(TokenType.DANS); // Optional 'DE' or 'D'
        final baseType = _advance().lexeme;
        decls.add(ArrayDeclarationNode(identifiers: ids, lowerBound: lower, upperBound: upper, baseType: baseType));
      } else {
        String type = _advance().lexeme;
        decls.add(VarDeclarationNode(identifiers: ids, type: type));
      }
    }
    _refuserMotReserveCommeNom("de variable");
    return decls;
  }

  /// Si le jeton courant est un mot réservé manifestement employé comme nom —
  /// il est suivi de ':', ',' ou '=' — lève l'erreur explicite.
  ///
  /// Sans ce contrôle, la boucle de déclaration s'arrête simplement (le mot
  /// n'est pas un identifiant) et `parse()` finit par ignorer la ligne en
  /// silence : le programme s'exécute alors sans la variable attendue, sans
  /// le moindre message.
  void _refuserMotReserveCommeNom(String role) {
    if (_isAtEnd() || !Lexer.isReservedWord(_peek().lexeme)) return;
    final suivant = _peekNext().type;
    if (suivant == TokenType.DEUX_POINTS ||
        suivant == TokenType.VIRGULE ||
        suivant == TokenType.EGAL) {
      _consumeIdentifier(role);
    }
  }

  List<ConstDeclarationNode> _constDeclarations() {
    final List<ConstDeclarationNode> decls = [];
    while (_check(TokenType.IDENTIFIANT)) {
      final name = _advance().lexeme;
      _consume(TokenType.EGAL, "= attendu.");
      final value = _expression();
      decls.add(ConstDeclarationNode(identifier: name, value: value));
    }
    _refuserMotReserveCommeNom("de constante");
    return decls;
  }

  FunctionDeclarationNode _functionDeclaration() {
    final name = _consumeIdentifier("de fonction").lexeme;
    _consume(TokenType.PAREN_OUVRANTE, "( attendue.");
    final params = _parameters();
    _consume(TokenType.PAREN_FERMANTE, ") attendue.");
    _consume(TokenType.DEUX_POINTS, ": attendu.");
    final returnType = _advance().lexeme;
    final localDecls = _localDeclarations();
    _consume(TokenType.DEBUT, "DEBUT attendu.");
    final body = _block(TokenType.FIN);
    _consume(TokenType.FIN, "FIN attendu.");
    return FunctionDeclarationNode(name: name, parameters: params, returnType: returnType, declarations: localDecls, body: body);
  }

  ProcedureDeclarationNode _procedureDeclaration() {
    final name = _consumeIdentifier("de procédure").lexeme;
    _consume(TokenType.PAREN_OUVRANTE, "( attendue.");
    final params = _parameters();
    _consume(TokenType.PAREN_FERMANTE, ") attendue.");
    final localDecls = _localDeclarations();
    _consume(TokenType.DEBUT, "DEBUT attendu.");
    final body = _block(TokenType.FIN);
    _consume(TokenType.FIN, "FIN attendu.");
    return ProcedureDeclarationNode(name: name, parameters: params, declarations: localDecls, body: body);
  }

  /// Déclarations locales (Variables / Constantes) d'une fonction/procédure,
  /// placées entre la signature et DEBUT 
  List<ASTNode> _localDeclarations() {
    final List<ASTNode> decls = [];
    while (!_check(TokenType.DEBUT) && !_isAtEnd()) {
      if (_match(TokenType.VAR)) { decls.addAll(_varDeclarations()); }
      else if (_match(TokenType.CONSTANTE)) { decls.addAll(_constDeclarations()); }
      else if (_check(TokenType.STRUCTURE) || _check(TokenType.TYPE)) { _throwNotImplemented(); }
      else { break; }
    }
    return decls;
  }

  /// Les déclarations de types personnalisés (`Type` / `Structure` /
  /// `Enregistrement`) sont reconnues par l'analyseur lexical mais pas encore
  /// traitées. On le signale explicitement plutôt que de les ignorer en
  /// silence : un programme qui en contient ne s'exécuterait pas comme prévu
  /// et l'étudiant n'aurait aucun indice sur la cause.
  Never _throwNotImplemented() {
    final mot = _peek().lexeme;
    throw "Erreur ligne ${_peek().line}: '$mot' n'est pas encore implémenté dans SenAlgo. "
        "Les types personnalisés (Type / Structure / Enregistrement) ne sont pas encore supportés ; "
        "utilise pour l'instant des variables simples ou des tableaux.";
  }

  List<Parameter> _parameters() {
    final List<Parameter> params = [];
    if (!_check(TokenType.PAREN_FERMANTE)) {
      do {
        // Statut donnée (par défaut) / résultat /
        // donnée-résultat, placé avant le nom du paramètre.
        ParamMode mode = ParamMode.donnee;
        if (_match(TokenType.DONNEE)) {
          if (_match(TokenType.MOINS)) {
            _consume(TokenType.RESULTAT, "'résultat' attendu après 'donnée-'.");
            mode = ParamMode.donneeResultat;
          } else {
            mode = ParamMode.donnee;
          }
        } else if (_match(TokenType.RESULTAT)) {
          mode = ParamMode.resultat;
        }
        final name = _consumeIdentifier("de paramètre").lexeme;
        // Paramètre tableau : nom(borneInf : borneSup) : tableau de type
        if (_match(TokenType.PAREN_OUVRANTE)) {
          final lower = _expression();
          _consume(TokenType.DEUX_POINTS, ": attendu.");
          final upper = _expression();
          _consume(TokenType.PAREN_FERMANTE, ") attendue.");
          _consume(TokenType.DEUX_POINTS, ": attendu.");
          _consume(TokenType.T_TABLEAU, "TABLEAU attendu.");
          _match(TokenType.DANS); // 'de'
          final baseType = _advance().lexeme;
          params.add(Parameter(name: name, type: 'tableau de $baseType', mode: mode, isArray: true, lowerBound: lower, upperBound: upper, baseType: baseType));
          continue;
        }
        _consume(TokenType.DEUX_POINTS, ": attendu.");
        if (_match(TokenType.T_TABLEAU)) {
          _match(TokenType.DANS);
          final baseType = _advance().lexeme;
          params.add(Parameter(name: name, type: 'tableau de $baseType', mode: mode, isArray: true, baseType: baseType));
        } else {
          final type = _advance().lexeme;
          params.add(Parameter(name: name, type: type, mode: mode));
        }
      } while (_match(TokenType.VIRGULE));
    }
    return params;
  }

  BlockNode _block(TokenType endToken) {
    final List<ASTNode> statements = [];
    while (!_check(endToken) && !_isAtEnd()) { statements.add(_statement()); }
    return BlockNode(statements: statements);
  }

  ASTNode _statement() {
    if (_match(TokenType.SI)) return _ifStatement(_previous());
    if (_match(TokenType.TANTQUE)) return _whileStatement(_previous());
    if (_match(TokenType.POUR)) return _forStatement(_previous());
    if (_match(TokenType.REPETER)) return _repeatStatement(_previous());
    if (_match(TokenType.SELON)) return _selonStatement(_previous());
    if (_match(TokenType.RETOURNER)) return _returnStatement(_previous());
    if (_match(TokenType.ECRIRE) || _match(TokenType.AFFICHER) || 
        _match(TokenType.LIRE) || _match(TokenType.SAISIR) ||
        _match(TokenType.ECRIRELN) || _match(TokenType.AFFICHERLN)) {
      return _customInstructionStatement(_previous());
    }
    if (_check(TokenType.IDENTIFIANT)) {
      if (_peekNext().type == TokenType.AFFECTATION) return _assignment();
      if (_peekNext().type == TokenType.CROCHET_OUVRANT || _peekNext().type == TokenType.PAREN_OUVRANTE) {
        // Could be an array assignment: t[i] <- value OR t(i) <- value
        final opening = _peekNext().type;
        final closing = (opening == TokenType.CROCHET_OUVRANT) ? TokenType.CROCHET_FERMANT : TokenType.PAREN_FERMANTE;
        
        int lookahead = _current + 1;
        int depth = 0;
        bool foundClosing = false;
        while (lookahead < tokens.length) {
          if (tokens[lookahead].type == opening) depth++;
          if (tokens[lookahead].type == closing) depth--;
          if (depth == 0) {
            lookahead++;
            foundClosing = true;
            break;
          }
          lookahead++;
        }
        
        if (foundClosing && lookahead < tokens.length && tokens[lookahead].type == TokenType.AFFECTATION) {
          return _arrayAssignment(opening, closing);
        }
      }
    }
    return _expressionStatement();
  }

  ASTNode _arrayAssignment(TokenType open, TokenType close) {
    final identifierToken = _consumeIdentifier("de tableau");
    _consume(open, "[ ou ( attendu.");
    final index = _expression();
    _consume(close, "] ou ) attendu.");
    _consume(TokenType.AFFECTATION, "<- attendu.");
    final value = _expression();
    return ArrayAssignmentNode(identifier: identifierToken.lexeme, index: index, value: value)..anchor = identifierToken;
  }

  ASTNode _customInstructionStatement(Token keyword) {
    List<ASTNode> args = [];
    if (_match(TokenType.PAREN_OUVRANTE)) {
      _dansGroupement(() {
        if (!_check(TokenType.PAREN_FERMANTE)) {
          do {
            args.add(_expression());
          } while (_match(TokenType.VIRGULE));
        }
      });
      _consume(TokenType.PAREN_FERMANTE, ") attendue.");
    } else {
      // Non-parenthesized version: ecrire a, b
      if (!_isAtEnd() && !_check(TokenType.FIN) && !_check(TokenType.FINSI) && 
          !_check(TokenType.SINON) && !_check(TokenType.SINONSI) && 
          !_check(TokenType.FINPOUR) && !_check(TokenType.FINTANTQUE)) {
        // Peek to see if there's at least one expression-like token
        if (_check(TokenType.IDENTIFIANT) || _check(TokenType.ENTIER) || 
            _check(TokenType.REEL) || _check(TokenType.CHAINE) || 
            _check(TokenType.BOOLEEN) || _check(TokenType.PAREN_OUVRANTE) ||
            _check(TokenType.NON) || _check(TokenType.MOINS)) {
          do {
            args.add(_expression());
          } while (_match(TokenType.VIRGULE));
        }
      }
    }
    return ExpressionStmtNode(expression: CallNode(callee: keyword.lexeme, arguments: args)..anchor = keyword);
  }

  ASTNode _ifStatement(Token anchor) {
    final condition = _dansGroupement(_expression);
    _consume(TokenType.ALORS, "ALORS attendu.");
    final List<ASTNode> thenStmts = [];
    final List<ElseIfNode> elseIfs = [];
    BlockNode? elseBranch;
    while (!_check(TokenType.SINONSI) && !_check(TokenType.SINON) && !_check(TokenType.FINSI) && !_isAtEnd()) { thenStmts.add(_statement()); }
    while (_match(TokenType.SINONSI)) {
      final elifCond = _dansGroupement(_expression);
      _consume(TokenType.ALORS, "ALORS attendu.");
      final List<ASTNode> elifStmts = [];
      while (!_check(TokenType.SINONSI) && !_check(TokenType.SINON) && !_check(TokenType.FINSI) && !_isAtEnd()) { elifStmts.add(_statement()); }
      elseIfs.add(ElseIfNode(condition: elifCond, body: BlockNode(statements: elifStmts)));
    }
    if (_match(TokenType.SINON)) {
      final List<ASTNode> elseStmts = [];
      while (!_check(TokenType.FINSI) && !_isAtEnd()) { elseStmts.add(_statement()); }
      elseBranch = BlockNode(statements: elseStmts);
    }
    _consume(TokenType.FINSI, "FINSI attendu.");
    return IfNode(condition: condition, thenBranch: BlockNode(statements: thenStmts), elseIfs: elseIfs, elseBranch: elseBranch)..anchor = anchor;
  }

  ASTNode _whileStatement(Token anchor) {
    final condition = _dansGroupement(_expression);
    _consume(TokenType.FAIRE, "FAIRE attendu.");
    final List<ASTNode> stmts = [];
    while (!_check(TokenType.FINTANTQUE) && !_isAtEnd()) { stmts.add(_statement()); }
    _consume(TokenType.FINTANTQUE, "FINTANTQUE attendu.");
    return WhileNode(condition: condition, body: BlockNode(statements: stmts))..anchor = anchor;
  }

  ASTNode _forStatement(Token anchor) {
    final id = _consumeIdentifier("de variable").lexeme;
    
    // Optional 'allant'
    _match(TokenType.ALLANT);
    
    // 'de' (DANS in keywords map) is mandatory in 'i de 1' or 'i allant de 1'
    _consume(TokenType.DANS, "Mot-clé 'de' attendu.");
    
    final start = _dansGroupement(_expression);
    _consume(TokenType.A, "à attendu.");
    final end = _dansGroupement(_expression);
    
    ASTNode? step;
    if (_match(TokenType.PAS)) {
      // Optional 'de' after 'pas'
      _match(TokenType.DANS);
      step = _expression();
    }
    
    _consume(TokenType.FAIRE, "FAIRE attendu.");
    final List<ASTNode> stmts = [];
    while (!_check(TokenType.FINPOUR) && !_isAtEnd()) { stmts.add(_statement()); }
    _consume(TokenType.FINPOUR, "FINPOUR attendu.");
    return ForNode(identifier: id, startValue: start, endValue: end, step: step, body: BlockNode(statements: stmts))..anchor = anchor;
  }

  ASTNode _repeatStatement(Token anchor) {
    final List<ASTNode> stmts = [];
    while (!_check(TokenType.JUSQUA) && !_isAtEnd()) { stmts.add(_statement()); }
    _consume(TokenType.JUSQUA, "jusqu'à attendu.");
    final condition = _expression();
    return RepeatNode(body: BlockNode(statements: stmts), condition: condition)..anchor = anchor;
  }

  ASTNode _returnStatement(Token anchor) {
    ASTNode? value;
    // La valeur de retour doit se trouver sur la MÊME ligne que "Retourner"
    // (même convention que les expressions, cf. _logicOr et suivants). Sans
    // cette contrainte, un "Retourner" seul happait l'instruction de la ligne
    // suivante et l'exécutait comme s'il s'agissait de sa valeur de retour.
    if (!_check(TokenType.POINT_VIRGULE) && !_check(TokenType.FIN) && _peek().line == anchor.line) {
      value = _expression();
    }
    return ReturnNode(value: value)..anchor = anchor;
  }

  /// "Selon expression Faire / valeur1 : traitement1 / ... / Sinon traitement
  /// par défaut / FinSelon" Chaque cas
  /// est une seule instruction (comme dans tous les exemples du cours), et
  /// la valeur du cas peut être soit une valeur littérale/expression
  /// (comparée par égalité), soit une comparaison ("< 1000"), éventuellement
  /// chaînée par et/ou ("≥ 1000 et < 3000").
  ASTNode _selonStatement(Token anchor) {
    final selonExpr = _dansGroupement(_expression);
    _consume(TokenType.FAIRE, "FAIRE attendu après SELON.");
    final List<SelonCaseNode> cases = [];
    BlockNode? defaultBranch;
    while (!_check(TokenType.FINCAS) && !_isAtEnd()) {
      if (_match(TokenType.SINON)) {
        defaultBranch = BlockNode(statements: [_statement()]);
        continue;
      }
      final guard = _selonCaseGuard(selonExpr);
      _consume(TokenType.DEUX_POINTS, ": attendu après la valeur du cas SELON.");
      final stmt = _statement();
      cases.add(SelonCaseNode(guard: guard, body: BlockNode(statements: [stmt])));
    }
    _consume(TokenType.FINCAS, "FINSELON attendu.");
    return SelonNode(expression: selonExpr, cases: cases, defaultBranch: defaultBranch)..anchor = anchor;
  }

  bool _isComparisonOp(TokenType t) =>
      t == TokenType.PLUS_PETIT || t == TokenType.PLUS_PETIT_EGAL ||
      t == TokenType.PLUS_GRAND || t == TokenType.PLUS_GRAND_EGAL ||
      t == TokenType.EGAL || t == TokenType.DIFFERENT;

  ASTNode _selonCaseGuard(ASTNode selonExpr) {
    if (_isComparisonOp(_peek().type)) {
      ASTNode expr = _selonComparison(selonExpr);
      while (_check(TokenType.ET) || _check(TokenType.OU)) {
        final combOp = _advance();
        final right = _selonComparison(selonExpr);
        expr = BinaryNode(left: expr, operator: combOp, right: right);
      }
      return expr;
    } else {
      final value = _term();
      final eqToken = Token(type: TokenType.EGAL, lexeme: '=', line: _peek().line, column: _peek().column);
      return BinaryNode(left: selonExpr, operator: eqToken, right: value);
    }
  }

  ASTNode _selonComparison(ASTNode selonExpr) {
    final op = _advance();
    final operand = _term();
    return BinaryNode(left: selonExpr, operator: op, right: operand);
  }

  ASTNode _assignment() {
    final identifierToken = _consumeIdentifier("de variable");
    final name = identifierToken.lexeme;
    _consume(TokenType.AFFECTATION, "<- attendu.");
    final value = _expression();
    return AssignmentNode(identifier: name, value: value)..anchor = identifierToken;
  }

  ASTNode _expressionStatement() { return ExpressionStmtNode(expression: _expression()); }

  /// Niveau d'imbrication des parenthèses et crochets en cours d'analyse.
  int _groupingDepth = 0;

  /// Indique si un opérateur binaire poursuit l'expression en cours.
  ///
  /// Le langage n'a pas de séparateur d'instructions : c'est le retour à la
  /// ligne qui joue ce rôle, donc un opérateur placé en début de ligne termine
  /// l'expression précédente. On peut néanmoins couper une ligne APRÈS un
  /// opérateur, celui-ci restant sur la ligne de son opérande gauche.
  ///
  /// Entre parenthèses ou crochets en revanche, aucune instruction ne peut
  /// commencer : les retours à la ligne y sont sans importance et l'expression
  /// se poursuit librement.
  bool _poursuitExpression() => _groupingDepth > 0 || _peek().line == _previous().line;

  /// Analyse [action] dans un contexte où un retour à la ligne ne termine pas
  /// l'expression, parce qu'un délimiteur explicite s'en charge : parenthèses
  /// et crochets, mais aussi les conditions fermées par un mot-clé
  /// (`Si … Alors`, `Tant que … Faire`, `Selon … Faire`) et les bornes d'un
  /// `Pour`, où aucune instruction ne peut commencer avant ce mot-clé.
  T _dansGroupement<T>(T Function() action) {
    _groupingDepth++;
    try {
      return action();
    } finally {
      _groupingDepth--;
    }
  }

  ASTNode _expression() => _logicOr();
  ASTNode _logicOr() {
    var expr = _logicAnd();
    while (_check(TokenType.OU) && _poursuitExpression()) { final op = _advance(); final right = _logicAnd(); expr = BinaryNode(left: expr, operator: op, right: right); }
    return expr;
  }
  ASTNode _logicAnd() {
    var expr = _equality();
    while (_check(TokenType.ET) && _poursuitExpression()) { final op = _advance(); final right = _equality(); expr = BinaryNode(left: expr, operator: op, right: right); }
    return expr;
  }
  ASTNode _equality() {
    var expr = _comparison();
    while ((_check(TokenType.EGAL) || _check(TokenType.DIFFERENT)) && _poursuitExpression()) { final op = _advance(); final right = _comparison(); expr = BinaryNode(left: expr, operator: op, right: right); }
    return expr;
  }
  ASTNode _comparison() {
    var expr = _term();
    while ((_check(TokenType.PLUS_PETIT) || _check(TokenType.PLUS_PETIT_EGAL) || _check(TokenType.PLUS_GRAND) || _check(TokenType.PLUS_GRAND_EGAL)) && _poursuitExpression()) {
      final op = _advance(); final right = _term(); expr = BinaryNode(left: expr, operator: op, right: right);
    }
    return expr;
  }
  ASTNode _term() {
    var expr = _factor();
    while ((_check(TokenType.PLUS) || _check(TokenType.MOINS)) && _poursuitExpression()) { final op = _advance(); final right = _factor(); expr = BinaryNode(left: expr, operator: op, right: right); }
    return expr;
  }
  ASTNode _factor() {
    var expr = _unary();
    while ((_check(TokenType.FOIS) || _check(TokenType.DIVISE) || _check(TokenType.DIV) || _check(TokenType.MOD)) && _poursuitExpression()) { final op = _advance(); final right = _unary(); expr = BinaryNode(left: expr, operator: op, right: right); }
    return expr;
  }
  ASTNode _unary() {
    if (_match(TokenType.NON) || _match(TokenType.MOINS)) { final op = _previous(); final right = _unary(); return UnaryNode(operator: op, right: right); }
    return _power();
  }
  /// La puissance est plus prioritaire que le moins unaire  `-2^2` vaut `-4`
  /// et associative **à droite** : `2^3^2` vaut `2^(3^2)`, soit 512.
  ///
  /// L'associativité à droite vient de l'appel récursif à [_unary] plutôt que
  /// d'une boucle ; ce même appel permet d'écrire `2^-3`.
  ASTNode _power() {
    final expr = _call();
    if (_check(TokenType.PUISSANCE) && _poursuitExpression()) {
      final op = _advance();
      return BinaryNode(left: expr, operator: op, right: _unary());
    }
    return expr;
  }
  ASTNode _call() {
    var expr = _primary();
    while (true) { 
      if (_match(TokenType.PAREN_OUVRANTE)) { 
        expr = _finishCall(expr); 
      } else if (_match(TokenType.CROCHET_OUVRANT)) {
        final index = _dansGroupement(_expression);
        _consume(TokenType.CROCHET_FERMANT, "] attendu.");
        if (expr is VariableNode) {
          expr = ArrayAccessNode(name: expr.name, index: index)..anchor = expr.name;
        } else {
          throw "Indexation invalide.";
        }
      } else { 
        break; 
      } 
    }
    return expr;
  }
  ASTNode _finishCall(ASTNode callee) {
    final List<ASTNode> args = [];
    _dansGroupement(() {
      if (!_check(TokenType.PAREN_FERMANTE)) { do { args.add(_expression()); } while (_match(TokenType.VIRGULE)); }
    });
    _consume(TokenType.PAREN_FERMANTE, ") attendue.");
    if (callee is VariableNode) { return CallNode(callee: callee.name.lexeme, arguments: args)..anchor = callee.name; }
    throw "Appel invalide.";
  }
  ASTNode _primary() {
    if (_match(TokenType.BOOLEEN)) return LiteralNode(value: _previous().literal)..anchor = _previous();
    if (_match(TokenType.ENTIER)) return LiteralNode(value: _previous().literal)..anchor = _previous();
    if (_match(TokenType.REEL)) return LiteralNode(value: _previous().literal)..anchor = _previous();
    if (_match(TokenType.CHAINE)) return LiteralNode(value: _previous().literal)..anchor = _previous();
    if (_match(TokenType.IDENTIFIANT) || 
        _match(TokenType.ECRIRE) || _match(TokenType.AFFICHER) || 
        _match(TokenType.LIRE) || _match(TokenType.SAISIR) ||
        _match(TokenType.ECRIRELN) || _match(TokenType.AFFICHERLN)) {
      final token = _previous();
      // Special case for lire/saisir as an expression without parents
      if ((token.type == TokenType.LIRE || token.type == TokenType.SAISIR) && !_check(TokenType.PAREN_OUVRANTE)) {
         return CallNode(callee: token.lexeme, arguments: [])..anchor = token;
      }
      return VariableNode(name: token)..anchor = token;
    }
    if (_match(TokenType.PAREN_OUVRANTE)) {
      final expr = _dansGroupement(_expression);
      _consume(TokenType.PAREN_FERMANTE, ") attendue.");
      return expr;
    }
    throw "Expression attendue ligne ${_peek().line}.";
  }

  bool _match(TokenType type) { if (_check(type)) { _advance(); return true; } return false; }
  bool _check(TokenType type) { if (_isAtEnd()) return false; return _peek().type == type; }
  Token _advance() { if (!_isAtEnd()) _current++; return _previous(); }
  bool _isAtEnd() => _peek().type == TokenType.EOF;
  Token _peek() => tokens[_current];
  Token _peekNext() => (_current + 1 >= tokens.length) ? tokens.last : tokens[_current + 1];
  Token _previous() => tokens[_current - 1];
  Token _consume(TokenType type, String msg) { if (_check(type)) return _advance(); throw "Erreur ligne ${_peek().line}: $msg"; }

  /// Consomme un nom (d'algorithme, de variable, de fonction...).
  ///
  /// Si le mot rencontré est un mot réservé du langage, le message le dit
  /// explicitement : sans cela, écrire « ALGORITHME Fin » produisait un
  /// « Nom de l'algorithme attendu » qui n'indiquait ni la cause ni la
  /// solution. [role] décrit ce qui était attendu, par exemple « de variable ».
  Token _consumeIdentifier(String role) {
    if (_check(TokenType.IDENTIFIANT)) return _advance();
    final token = _peek();
    if (Lexer.isReservedWord(token.lexeme)) {
      throw "Erreur ligne ${token.line}: '${token.lexeme}' est un mot réservé du langage "
          "et ne peut pas servir de nom $role. Choisis un autre nom "
          "(par exemple '${token.lexeme}1' ou 'Mon${token.lexeme}').";
    }
    throw "Erreur ligne ${token.line}: nom $role attendu.";
  }
}
