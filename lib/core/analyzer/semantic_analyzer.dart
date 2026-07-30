import '../ast/ast.dart';
import '../lexer/token.dart';
import 'types.dart';

/// Signalement produit par l'analyse sémantique.
///
/// Ce sont des AVERTISSEMENTS : ils n'empêchent jamais l'exécution. L'analyse
/// n'a pas vocation à se substituer au jugement de l'utilisateur, seulement à
/// attirer son attention sur ce qui est très probablement une erreur.
class SemanticWarning {
  final String message;
  final int line;
  final int column;

  const SemanticWarning({required this.message, required this.line, this.column = 0});

  @override
  String toString() => 'Ligne $line : $message';
}

/// Portée lexicale : le programme principal, ou le corps d'un sous-programme.
class _Portee {
  final Map<String, TypeSenAlgo> variables = {};
  final _Portee? parent;

  _Portee({this.parent});

  TypeSenAlgo? chercher(String nom) => variables[nom] ?? parent?.chercher(nom);
  bool contient(String nom) => chercher(nom) != null;
  void declarer(String nom, TypeSenAlgo type) => variables[nom] = type;
}

/// Signature d'une fonction ou d'une procédure.
class _Signature {
  final List<Parameter> parametres;
  final TypeSenAlgo retour;
  final bool estFonction;

  const _Signature({required this.parametres, required this.retour, required this.estFonction});
}

/// Vérifie la cohérence d'un programme après l'analyse syntaxique : variables
/// déclarées, types des affectations, conditions booléennes, indices entiers,
/// nombre d'arguments des appels.
///
/// Principe directeur : **ne jamais signaler ce dont on n'est pas sûr**. Dès
/// qu'un type est indéterminé, l'analyse se tait. Un faux avertissement coûte
/// plus cher qu'un oubli, puisqu'il envoie l'utilisateur chercher un problème
/// inexistant.
class SemanticAnalyzer implements ASTVisitor<TypeSenAlgo> {
  final List<SemanticWarning> warnings = [];
  final Map<String, _Signature> _signatures = {};

  _Portee _portee = _Portee();

  /// Type de retour attendu dans le corps du sous-programme en cours, `null`
  /// dans le programme principal.
  TypeSenAlgo? _retourAttendu;

  /// Fonctions intégrées : leur arité n'est pas vérifiée et leur type de
  /// retour est fixé ici.
  static const _entreesSorties = {'ecrire', 'écrire', 'afficher', 'ecrireln', 'écrireln', 'afficherln'};
  static const _lectures = {'lire', 'saisir'};

  /// Analyse [programme] et renvoie les avertissements, du premier au dernier
  /// dans l'ordre du texte.
  List<SemanticWarning> analyser(ProgramNode programme) {
    warnings.clear();
    _signatures.clear();
    _portee = _Portee();

    // Les sous-programmes sont recensés d'abord : un appel peut précéder la
    // déclaration dans le texte.
    for (final decl in programme.declarations) {
      if (decl is FunctionDeclarationNode) {
        _signatures[decl.name] = _Signature(
          parametres: decl.parameters,
          retour: TypeSenAlgo.depuisNom(decl.returnType),
          estFonction: true,
        );
      } else if (decl is ProcedureDeclarationNode) {
        _signatures[decl.name] = _Signature(
          parametres: decl.parameters,
          retour: TypeSenAlgo.vide,
          estFonction: false,
        );
      }
    }

    for (final decl in programme.declarations) {
      decl.accept(this);
    }
    programme.body.accept(this);

    warnings.sort((a, b) => a.line.compareTo(b.line));
    return List.unmodifiable(warnings);
  }

  void _signaler(String message, Token? ancre) {
    warnings.add(SemanticWarning(
      message: message,
      line: ancre?.line ?? 0,
      column: ancre?.column ?? 0,
    ));
  }

  // --------------------------------------------------------------- déclarations

  @override
  TypeSenAlgo visitProgram(ProgramNode node) => TypeSenAlgo.vide;

  @override
  TypeSenAlgo visitVarDeclaration(VarDeclarationNode node) {
    final type = TypeSenAlgo.depuisNom(node.type);
    for (final id in node.identifiers) {
      _portee.declarer(id, type);
    }
    return TypeSenAlgo.vide;
  }

  @override
  TypeSenAlgo visitConstDeclaration(ConstDeclarationNode node) {
    _portee.declarer(node.identifier, node.value.accept(this));
    return TypeSenAlgo.vide;
  }

  @override
  TypeSenAlgo visitArrayDeclaration(ArrayDeclarationNode node) {
    final borneInf = node.lowerBound.accept(this);
    final borneSup = node.upperBound.accept(this);
    for (final borne in [borneInf, borneSup]) {
      if (borne.estConnu && borne.base != TypeBase.entier) {
        _signaler(
          "les bornes d'un tableau doivent être des entiers, pas ${_article(borne)}.",
          node.anchor,
        );
        break;
      }
    }
    final type = TypeSenAlgo.tableauDe(node.baseType);
    for (final id in node.identifiers) {
      _portee.declarer(id, type);
    }
    return TypeSenAlgo.vide;
  }

  @override
  TypeSenAlgo visitTypeDeclaration(TypeDeclarationNode node) => TypeSenAlgo.vide;

  @override
  TypeSenAlgo visitFunctionDeclaration(FunctionDeclarationNode node) {
    _analyserSousProgramme(node.parameters, node.declarations, node.body,
        retour: TypeSenAlgo.depuisNom(node.returnType));
    return TypeSenAlgo.vide;
  }

  @override
  TypeSenAlgo visitProcedureDeclaration(ProcedureDeclarationNode node) {
    _analyserSousProgramme(node.parameters, node.declarations, node.body, retour: null);
    return TypeSenAlgo.vide;
  }

  void _analyserSousProgramme(
    List<Parameter> parametres,
    List<ASTNode> declarations,
    BlockNode corps, {
    required TypeSenAlgo? retour,
  }) {
    final porteeAppelante = _portee;
    final retourAppelant = _retourAttendu;
    _portee = _Portee(parent: porteeAppelante);
    _retourAttendu = retour;

    for (final p in parametres) {
      _portee.declarer(
        p.name,
        p.isArray ? TypeSenAlgo.tableauDe(p.baseType ?? '') : TypeSenAlgo.depuisNom(p.type),
      );
    }
    for (final d in declarations) {
      d.accept(this);
    }
    corps.accept(this);

    _portee = porteeAppelante;
    _retourAttendu = retourAppelant;
  }

  // --------------------------------------------------------------- instructions

  @override
  TypeSenAlgo visitBlock(BlockNode node) {
    for (final s in node.statements) {
      s.accept(this);
    }
    return TypeSenAlgo.vide;
  }

  @override
  TypeSenAlgo visitExpressionStmt(ExpressionStmtNode node) {
    node.expression.accept(this);
    return TypeSenAlgo.vide;
  }

  @override
  TypeSenAlgo visitAssignment(AssignmentNode node) {
    final valeur = node.value.accept(this);
    final cible = _portee.chercher(node.identifier);
    if (cible == null) {
      _signaler("la variable '${node.identifier}' n'est pas déclarée.", node.anchor);
      return TypeSenAlgo.vide;
    }
    if (!cible.accepte(valeur)) {
      _signaler(_messageAffectation(node.identifier, cible, valeur), node.anchor);
    }
    return TypeSenAlgo.vide;
  }

  String _messageAffectation(String nom, TypeSenAlgo cible, TypeSenAlgo valeur) {
    if (cible.base == TypeBase.entier && valeur.base == TypeBase.reel) {
      return "'$nom' est un entier : lui affecter un réel perdrait la partie décimale.";
    }
    return "'$nom' est ${_article(cible)}, mais la valeur affectée est ${_article(valeur)}.";
  }

  String _article(TypeSenAlgo t) {
    switch (t.base) {
      case TypeBase.entier:
        return 'un entier';
      case TypeBase.reel:
        return 'un réel';
      case TypeBase.booleen:
        return 'un booléen';
      case TypeBase.caractere:
        return 'un caractère';
      case TypeBase.chaine:
        return 'une chaîne';
      case TypeBase.tableau:
        return 'un tableau';
      default:
        return 'de type indéterminé';
    }
  }

  @override
  TypeSenAlgo visitArrayAssignment(ArrayAssignmentNode node) {
    final valeur = node.value.accept(this);
    _verifierIndice(node.index.accept(this), node.anchor);
    final tableau = _portee.chercher(node.identifier);
    if (tableau == null) {
      _signaler("le tableau '${node.identifier}' n'est pas déclaré.", node.anchor);
      return TypeSenAlgo.vide;
    }
    if (tableau.estConnu && !tableau.estTableau) {
      _signaler("'${node.identifier}' n'est pas un tableau : ${_article(tableau)}.", node.anchor);
      return TypeSenAlgo.vide;
    }
    final attendu = TypeSenAlgo(tableau.element);
    if (!attendu.accepte(valeur)) {
      _signaler(
        "le tableau '${node.identifier}' contient ${_article(attendu)}, "
        "mais la valeur affectée est ${_article(valeur)}.",
        node.anchor,
      );
    }
    return TypeSenAlgo.vide;
  }

  void _verifierIndice(TypeSenAlgo type, Token? ancre) {
    if (type.estConnu && type.base != TypeBase.entier) {
      _signaler("un indice de tableau doit être un entier, pas ${_article(type)}.", ancre);
    }
  }

  void _verifierCondition(TypeSenAlgo type, String contexte, Token? ancre) {
    if (type.estConnu && type.base != TypeBase.booleen) {
      _signaler(
        "la condition $contexte doit être vraie ou fausse, or elle vaut ${_article(type)}.",
        ancre,
      );
    }
  }

  @override
  TypeSenAlgo visitIf(IfNode node) {
    _verifierCondition(node.condition.accept(this), "d'un SI", node.anchor);
    node.thenBranch.accept(this);
    for (final ei in node.elseIfs) {
      _verifierCondition(ei.condition.accept(this), "d'un SINONSI", node.anchor);
      ei.body.accept(this);
    }
    node.elseBranch?.accept(this);
    return TypeSenAlgo.vide;
  }

  @override
  TypeSenAlgo visitWhile(WhileNode node) {
    _verifierCondition(node.condition.accept(this), "d'un TANT QUE", node.anchor);
    node.body.accept(this);
    return TypeSenAlgo.vide;
  }

  @override
  TypeSenAlgo visitRepeat(RepeatNode node) {
    node.body.accept(this);
    _verifierCondition(node.condition.accept(this), "d'un JUSQU'À", node.anchor);
    return TypeSenAlgo.vide;
  }

  @override
  TypeSenAlgo visitFor(ForNode node) {
    final debut = node.startValue.accept(this);
    final fin = node.endValue.accept(this);
    final pas = node.step?.accept(this);
    for (final t in [debut, fin, if (pas != null) pas]) {
      if (t.estConnu && t.base != TypeBase.entier) {
        _signaler("les bornes d'un POUR doivent être des entiers, pas ${_article(t)}.", node.anchor);
        break;
      }
    }
    // La variable de boucle est déclarée implicitement si elle ne l'a pas été.
    if (!_portee.contient(node.identifier)) {
      _portee.declarer(node.identifier, TypeSenAlgo.entier);
    }
    node.body.accept(this);
    return TypeSenAlgo.vide;
  }

  @override
  TypeSenAlgo visitSelon(SelonNode node) {
    node.expression.accept(this);
    for (final c in node.cases) {
      c.guard.accept(this);
      c.body.accept(this);
    }
    node.defaultBranch?.accept(this);
    return TypeSenAlgo.vide;
  }

  @override
  TypeSenAlgo visitReturn(ReturnNode node) {
    final valeur = node.value?.accept(this) ?? TypeSenAlgo.vide;
    final attendu = _retourAttendu;
    if (attendu == null) {
      if (node.value != null) {
        _signaler("une procédure ne renvoie pas de valeur : 'Retourner' doit être employé seul.", node.anchor);
      }
      return TypeSenAlgo.vide;
    }
    if (node.value == null) {
      _signaler("cette fonction doit renvoyer ${_article(attendu)}.", node.anchor);
    } else if (!attendu.accepte(valeur)) {
      _signaler(
        "cette fonction déclare renvoyer ${_article(attendu)}, mais la valeur renvoyée est ${_article(valeur)}.",
        node.anchor,
      );
    }
    return TypeSenAlgo.vide;
  }

  // ---------------------------------------------------------------- expressions

  @override
  TypeSenAlgo visitLiteral(LiteralNode node) {
    final v = node.value;
    if (v is int) return TypeSenAlgo.entier;
    if (v is double) return TypeSenAlgo.reel;
    if (v is bool) return TypeSenAlgo.booleen;
    if (v is String) return TypeSenAlgo.chaine;
    return TypeSenAlgo.inconnu;
  }

  @override
  TypeSenAlgo visitVariable(VariableNode node) {
    final nom = node.name.lexeme;
    final type = _portee.chercher(nom);
    if (type == null) {
      _signaler("la variable '$nom' n'est pas déclarée.", node.name);
      return TypeSenAlgo.inconnu;
    }
    return type;
  }

  @override
  TypeSenAlgo visitArrayAccess(ArrayAccessNode node) {
    _verifierIndice(node.index.accept(this), node.name);
    final nom = node.name.lexeme;
    final type = _portee.chercher(nom);
    if (type == null) {
      _signaler("la variable '$nom' n'est pas déclarée.", node.name);
      return TypeSenAlgo.inconnu;
    }
    if (type.estConnu && !type.estTableau) {
      _signaler("'$nom' n'est pas un tableau : ${_article(type)}.", node.name);
      return TypeSenAlgo.inconnu;
    }
    return TypeSenAlgo(type.element);
  }

  @override
  TypeSenAlgo visitUnary(UnaryNode node) {
    final droite = node.right.accept(this);
    if (node.operator.type == TokenType.NON) {
      if (droite.estConnu && droite.base != TypeBase.booleen) {
        _signaler("'NON' s'applique à une valeur vraie ou fausse, pas à ${_article(droite)}.", node.operator);
      }
      return TypeSenAlgo.booleen;
    }
    if (droite.estConnu && !droite.estNumerique) {
      _signaler("le signe '-' s'applique à un nombre, pas à ${_article(droite)}.", node.operator);
      return TypeSenAlgo.inconnu;
    }
    return droite;
  }

  @override
  TypeSenAlgo visitBinary(BinaryNode node) {
    final g = node.left.accept(this);
    final d = node.right.accept(this);
    final op = node.operator;

    switch (op.type) {
      case TokenType.ET:
      case TokenType.OU:
        for (final t in [g, d]) {
          if (t.estConnu && t.base != TypeBase.booleen) {
            _signaler(
              "'${op.lexeme}' relie deux conditions vraies ou fausses, or l'une vaut ${_article(t)}.",
              op,
            );
            break;
          }
        }
        return TypeSenAlgo.booleen;

      case TokenType.EGAL:
      case TokenType.DIFFERENT:
        if (g.estConnu && d.estConnu && !g.accepte(d) && !d.accepte(g)) {
          _signaler("on compare ${_article(g)} avec ${_article(d)} : la comparaison est toujours fausse.", op);
        }
        return TypeSenAlgo.booleen;

      case TokenType.PLUS_PETIT:
      case TokenType.PLUS_PETIT_EGAL:
      case TokenType.PLUS_GRAND:
      case TokenType.PLUS_GRAND_EGAL:
        if (g.estConnu && d.estConnu && !(g.estNumerique && d.estNumerique) && g.base != d.base) {
          _signaler("on ne peut pas comparer ${_article(g)} et ${_article(d)}.", op);
        }
        return TypeSenAlgo.booleen;

      case TokenType.PLUS:
        // Le '+' concatène dès qu'une des deux valeurs est une chaîne.
        if (g.base == TypeBase.chaine || d.base == TypeBase.chaine) return TypeSenAlgo.chaine;
        return _resultatArithmetique(g, d, op);

      case TokenType.MOINS:
      case TokenType.FOIS:
      // La puissance suit la même règle : deux entiers donnent un entier,
      // un réel quelque part donne un réel.
      case TokenType.PUISSANCE:
        return _resultatArithmetique(g, d, op);

      case TokenType.DIVISE:
        _verifierNumerique(g, d, op);
        return TypeSenAlgo.reel;

      case TokenType.DIV:
      case TokenType.MOD:
        for (final t in [g, d]) {
          if (t.estConnu && t.base != TypeBase.entier) {
            _signaler("'${op.lexeme}' s'applique à des entiers, pas à ${_article(t)}.", op);
            break;
          }
        }
        return TypeSenAlgo.entier;

      default:
        return TypeSenAlgo.inconnu;
    }
  }

  void _verifierNumerique(TypeSenAlgo g, TypeSenAlgo d, Token op) {
    for (final t in [g, d]) {
      if (t.estConnu && !t.estNumerique) {
        _signaler("'${op.lexeme}' s'applique à des nombres, pas à ${_article(t)}.", op);
        return;
      }
    }
  }

  TypeSenAlgo _resultatArithmetique(TypeSenAlgo g, TypeSenAlgo d, Token op) {
    _verifierNumerique(g, d, op);
    if (!g.estConnu || !d.estConnu) return TypeSenAlgo.inconnu;
    if (!g.estNumerique || !d.estNumerique) return TypeSenAlgo.inconnu;
    // Un seul réel suffit à rendre le résultat réel.
    return (g.base == TypeBase.reel || d.base == TypeBase.reel) ? TypeSenAlgo.reel : TypeSenAlgo.entier;
  }

  @override
  TypeSenAlgo visitCall(CallNode node) {
    final nom = node.callee;
    final nomMinuscule = nom.toLowerCase();

    if (_entreesSorties.contains(nomMinuscule)) {
      for (final a in node.arguments) {
        a.accept(this);
      }
      return TypeSenAlgo.vide;
    }

    if (_lectures.contains(nomMinuscule)) {
      // La valeur saisie est convertie selon la variable qui la reçoit : on ne
      // peut pas lui attribuer de type a priori.
      for (final a in node.arguments) {
        a.accept(this);
      }
      return TypeSenAlgo.inconnu;
    }

    if (nomMinuscule == 'abs') {
      final t = node.arguments.isEmpty ? TypeSenAlgo.inconnu : node.arguments.first.accept(this);
      if (t.estConnu && !t.estNumerique) {
        _signaler("'abs' s'applique à un nombre, pas à ${_article(t)}.", node.anchor);
      }
      return t.estNumerique ? t : TypeSenAlgo.inconnu;
    }

    if (nomMinuscule == 'racine' || nomMinuscule == 'sqrt') {
      final t = node.arguments.isEmpty ? TypeSenAlgo.inconnu : node.arguments.first.accept(this);
      if (t.estConnu && !t.estNumerique) {
        _signaler("'$nom' s'applique à un nombre, pas à ${_article(t)}.", node.anchor);
      }
      return TypeSenAlgo.reel;
    }

    // Accès à un tableau écrit avec des parenthèses : t(i).
    final variable = _portee.chercher(nom);
    if (variable != null && variable.estTableau) {
      if (node.arguments.length == 1) {
        _verifierIndice(node.arguments.first.accept(this), node.anchor);
      } else {
        _signaler("l'accès au tableau '$nom' demande exactement un indice.", node.anchor);
      }
      return TypeSenAlgo(variable.element);
    }

    final signature = _signatures[nom];
    if (signature == null) {
      for (final a in node.arguments) {
        a.accept(this);
      }
      _signaler("'$nom' n'est ni une fonction, ni une procédure, ni un tableau connu.", node.anchor);
      return TypeSenAlgo.inconnu;
    }

    if (node.arguments.length != signature.parametres.length) {
      _signaler(
        "'$nom' attend ${signature.parametres.length} argument(s), "
        "mais ${node.arguments.length} lui sont fournis.",
        node.anchor,
      );
    }

    for (var i = 0; i < node.arguments.length; i++) {
      final typeArg = node.arguments[i].accept(this);
      if (i >= signature.parametres.length) continue;
      final p = signature.parametres[i];
      final attendu = p.isArray
          ? TypeSenAlgo.tableauDe(p.baseType ?? '')
          : TypeSenAlgo.depuisNom(p.type);
      if (!attendu.accepte(typeArg)) {
        _signaler(
          "le paramètre '${p.name}' de '$nom' attend ${_article(attendu)}, "
          "mais l'argument fourni est ${_article(typeArg)}.",
          node.anchor,
        );
      }
      // Un paramètre de sortie doit recevoir quelque chose où écrire.
      if (p.mode != ParamMode.donnee) {
        final arg = node.arguments[i];
        if (arg is! VariableNode && arg is! ArrayAccessNode) {
          _signaler(
            "le paramètre '${p.name}' de '$nom' est un paramètre de sortie : "
            "il doit recevoir une variable, pas une expression.",
            node.anchor,
          );
        }
      }
    }

    return signature.estFonction ? signature.retour : TypeSenAlgo.vide;
  }
}
