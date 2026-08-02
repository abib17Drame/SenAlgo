import '../ast/ast.dart';
import '../lexer/token.dart';
import 'types.dart';

/// Gravité d'un signalement de l'analyse sémantique.
enum Severite {
  /// Le programme ne peut pas s'exécuter correctement : affecter une chaîne à
  /// un entier, tester une condition qui n'est pas booléenne, indicer un
  /// tableau avec un réel. L'exécution est refusée.
  erreur,

  /// Le programme tourne, mais fait probablement autre chose que ce qui était
  /// voulu : affecter un réel à un entier tronque la valeur, comparer une
  /// chaîne à un entier donne toujours faux. L'utilisateur décide.
  avertissement,
}

/// Signalement produit par l'analyse sémantique.
///
/// La distinction entre [Severite.erreur] et [Severite.avertissement] est le
/// cœur du dispositif : une erreur empêche l'exécution, un avertissement la
/// laisse passer. Le partage se fait sur un critère simple : l'analyse
/// bloque-t-elle sur quelque chose dont elle est certaine ? Dès qu'un
/// programme défendable pourrait déclencher le signalement, il reste un
/// avertissement.
class SemanticDiagnostic {
  final String message;
  final int line;
  final int column;
  final Severite severite;

  const SemanticDiagnostic({
    required this.message,
    required this.line,
    this.column = 0,
    this.severite = Severite.erreur,
  });

  bool get estErreur => severite == Severite.erreur;

  @override
  String toString() => 'Ligne $line : $message';
}

/// Portée lexicale : le programme principal, ou le corps d'un sous-programme.
class _Portee {
  final Map<String, TypeSenAlgo> variables = {};

  /// Noms déclarés dans un bloc CONSTANTES : ils ne peuvent plus recevoir
  /// d'affectation.
  final Set<String> constantes = {};

  final _Portee? parent;

  _Portee({this.parent});

  TypeSenAlgo? chercher(String nom) => variables[nom] ?? parent?.chercher(nom);
  bool contient(String nom) => chercher(nom) != null;
  void declarer(String nom, TypeSenAlgo type) => variables[nom] = type;

  void declarerConstante(String nom, TypeSenAlgo type) {
    variables[nom] = type;
    constantes.add(nom);
  }

  bool estConstante(String nom) =>
      constantes.contains(nom) || (parent?.estConstante(nom) ?? false);
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
/// inexistant, et depuis que les erreurs bloquent l'exécution, il coûte même
/// bien davantage.
class SemanticAnalyzer implements ASTVisitor<TypeSenAlgo> {
  final List<SemanticDiagnostic> diagnostics = [];
  final Map<String, _Signature> _signatures = {};

  _Portee _portee = _Portee();

  /// Type de retour attendu dans le corps du sous-programme en cours, `null`
  /// dans le programme principal.
  TypeSenAlgo? _retourAttendu;

  /// Fonctions intégrées : leur arité n'est pas vérifiée et leur type de
  /// retour est fixé ici.
  static const _entreesSorties = {'ecrire', 'écrire', 'afficher', 'ecrireln', 'écrireln', 'afficherln'};
  static const _lectures = {'lire', 'saisir'};

  /// Analyse [programme] et renvoie les signalements, du premier au dernier
  /// dans l'ordre du texte, erreurs et avertissements mêlés.
  List<SemanticDiagnostic> analyser(ProgramNode programme) {
    diagnostics.clear();
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

    diagnostics.sort((a, b) => a.line.compareTo(b.line));
    return List.unmodifiable(diagnostics);
  }

  /// Signale un fait certain, qui empêchera le programme de démarrer.
  void _erreur(String message, Token? ancre) =>
      _signaler(message, ancre, Severite.erreur);

  /// Signale un doute : le programme démarrera quand même.
  void _avertir(String message, Token? ancre) =>
      _signaler(message, ancre, Severite.avertissement);

  void _signaler(String message, Token? ancre, Severite severite) {
    diagnostics.add(SemanticDiagnostic(
      message: message,
      line: ancre?.line ?? 0,
      column: ancre?.column ?? 0,
      severite: severite,
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
    _portee.declarerConstante(node.identifier, node.value.accept(this));
    return TypeSenAlgo.vide;
  }

  @override
  TypeSenAlgo visitArrayDeclaration(ArrayDeclarationNode node) {
    final borneInf = node.lowerBound.accept(this);
    final borneSup = node.upperBound.accept(this);
    for (final borne in [borneInf, borneSup]) {
      if (borne.estConnu && borne.base != TypeBase.entier) {
        _erreur(
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
      _erreur("la variable '${node.identifier}' n'est pas déclarée.", node.anchor);
      return TypeSenAlgo.vide;
    }
    if (_portee.estConstante(node.identifier)) {
      _erreur(
        "'${node.identifier}' est une constante : sa valeur est fixée à la "
        "déclaration et ne peut plus changer.",
        node.anchor,
      );
      return TypeSenAlgo.vide;
    }
    if (!cible.accepte(valeur)) {
      _signalerAffectation(node.identifier, cible, valeur, node.anchor);
    }
    return TypeSenAlgo.vide;
  }

  /// Un mélange de types est-il seulement douteux, ou franchement faux ?
  ///
  /// Deux rétrécissements ont un sens défini, et l'exécution les réalise pour
  /// de bon : un réel rangé dans un entier perd sa partie décimale, une chaîne
  /// rangée dans un caractère tient si elle est assez courte. Ceux-là
  /// avertissent. Tout le reste bloque.
  ///
  /// Une seule fonction pour toutes les situations où une valeur entre dans
  /// une case typée, faute de quoi la même faute serait tantôt un
  /// avertissement dans une affectation, tantôt une erreur dans un appel.
  Severite _severitePour(TypeSenAlgo cible, TypeSenAlgo valeur) {
    if (cible.base == TypeBase.entier && valeur.base == TypeBase.reel) {
      return Severite.avertissement;
    }
    if (cible.base == TypeBase.caractere && valeur.base == TypeBase.chaine) {
      return Severite.avertissement;
    }
    return Severite.erreur;
  }

  /// Signale une affectation dont les types ne concordent pas.
  void _signalerAffectation(String nom, TypeSenAlgo cible, TypeSenAlgo valeur, Token? ancre) {
    if (cible.base == TypeBase.entier && valeur.base == TypeBase.reel) {
      _avertir("'$nom' est un entier : lui affecter un réel perdrait la partie décimale.", ancre);
      return;
    }
    if (cible.base == TypeBase.caractere && valeur.base == TypeBase.chaine) {
      _avertir(
        "'$nom' est un caractère : un texte entre guillemets doubles est une "
        "chaîne. Écrivez-le entre apostrophes, et sur une seule lettre.",
        ancre,
      );
      return;
    }
    _erreur("'$nom' est ${_article(cible)}, mais la valeur affectée est ${_article(valeur)}.", ancre);
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
      _erreur("le tableau '${node.identifier}' n'est pas déclaré.", node.anchor);
      return TypeSenAlgo.vide;
    }
    if (tableau.estConnu && !tableau.estTableau) {
      _erreur("'${node.identifier}' n'est pas un tableau : ${_article(tableau)}.", node.anchor);
      return TypeSenAlgo.vide;
    }
    final attendu = TypeSenAlgo(tableau.element);
    if (!attendu.accepte(valeur)) {
      _signaler(
        "le tableau '${node.identifier}' contient ${_article(attendu)}, "
        "mais la valeur affectée est ${_article(valeur)}.",
        node.anchor,
        _severitePour(attendu, valeur),
      );
    }
    return TypeSenAlgo.vide;
  }

  void _verifierIndice(TypeSenAlgo type, Token? ancre) {
    if (type.estConnu && type.base != TypeBase.entier) {
      _erreur("un indice de tableau doit être un entier, pas ${_article(type)}.", ancre);
    }
  }

  void _verifierCondition(TypeSenAlgo type, String contexte, Token? ancre) {
    if (type.estConnu && type.base != TypeBase.booleen) {
      _erreur(
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
    final List<TypeSenAlgo> temps = [debut, fin];
    if (pas != null) {
      temps.add(pas);
    }
    for (final t in temps) {
      if (t.estConnu && t.base != TypeBase.entier) {
        _erreur("les bornes d'un POUR doivent être des entiers, pas ${_article(t)}.", node.anchor);
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
        _erreur("une procédure ne renvoie pas de valeur : 'Retourner' doit être employé seul.", node.anchor);
      }
      return TypeSenAlgo.vide;
    }
    if (node.value == null) {
      _erreur("cette fonction doit renvoyer ${_article(attendu)}.", node.anchor);
    } else if (!attendu.accepte(valeur)) {
      _signaler(
        "cette fonction déclare renvoyer ${_article(attendu)}, mais la valeur renvoyée est ${_article(valeur)}.",
        node.anchor,
        _severitePour(attendu, valeur),
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
    // Ce sont les guillemets qui décident, pas la longueur : 'o' est un
    // caractère, "o" est une chaîne d'une lettre. Rien n'est deviné.
    if (v is String) return node.estCaractere ? TypeSenAlgo.caractere : TypeSenAlgo.chaine;
    return TypeSenAlgo.inconnu;
  }

  @override
  TypeSenAlgo visitVariable(VariableNode node) {
    final nom = node.name.lexeme;
    final type = _portee.chercher(nom);
    if (type == null) {
      _erreur("la variable '$nom' n'est pas déclarée.", node.name);
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
      _erreur("la variable '$nom' n'est pas déclarée.", node.name);
      return TypeSenAlgo.inconnu;
    }
    if (type.estConnu && !type.estTableau) {
      _erreur("'$nom' n'est pas un tableau : ${_article(type)}.", node.name);
      return TypeSenAlgo.inconnu;
    }
    return TypeSenAlgo(type.element);
  }

  @override
  TypeSenAlgo visitUnary(UnaryNode node) {
    final droite = node.right.accept(this);
    if (node.operator.type == TokenType.NON) {
      if (droite.estConnu && droite.base != TypeBase.booleen) {
        _erreur("'NON' s'applique à une valeur vraie ou fausse, pas à ${_article(droite)}.", node.operator);
      }
      return TypeSenAlgo.booleen;
    }
    if (droite.estConnu && !droite.estNumerique) {
      _erreur("le signe '-' s'applique à un nombre, pas à ${_article(droite)}.", node.operator);
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
            _erreur(
              "'${op.lexeme}' relie deux conditions vraies ou fausses, or l'une vaut ${_article(t)}.",
              op,
            );
            break;
          }
        }
        return TypeSenAlgo.booleen;

      case TokenType.EGAL:
      case TokenType.DIFFERENT:
        // Comparer deux types étrangers a un résultat parfaitement défini :
        // c'est toujours faux. Le programme tourne, il ne fait simplement pas
        // ce qu'on croit : un avertissement, pas une erreur.
        if (g.estConnu && d.estConnu && !g.accepte(d) && !d.accepte(g)) {
          _avertir("on compare ${_article(g)} avec ${_article(d)} : la comparaison est toujours fausse.", op);
        }
        return TypeSenAlgo.booleen;

      case TokenType.PLUS_PETIT:
      case TokenType.PLUS_PETIT_EGAL:
      case TokenType.PLUS_GRAND:
      case TokenType.PLUS_GRAND_EGAL:
        if (g.estConnu && d.estConnu && !(g.estNumerique && d.estNumerique) && g.base != d.base) {
          _erreur("on ne peut pas comparer ${_article(g)} et ${_article(d)}.", op);
        }
        return TypeSenAlgo.booleen;

      case TokenType.PLUS:
        // Le '+' concatène dès qu'une des deux valeurs est textuelle. Les
        // caractères en font partie : `c1 + c2` forme un mot de deux lettres,
        // ce que l'interpréteur fait déjà.
        const textuels = {TypeBase.chaine, TypeBase.caractere};
        if (textuels.contains(g.base) || textuels.contains(d.base)) return TypeSenAlgo.chaine;
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
            _erreur("'${op.lexeme}' s'applique à des entiers, pas à ${_article(t)}.", op);
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
        _erreur("'${op.lexeme}' s'applique à des nombres, pas à ${_article(t)}.", op);
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
      // peut pas lui attribuer de type a priori. En revanche la cible, elle,
      // doit pouvoir recevoir quelque chose.
      for (final a in node.arguments) {
        final type = a.accept(this);
        if (a is! VariableNode) continue;
        final cible = a.name.lexeme;
        if (_portee.estConstante(cible)) {
          _erreur("'$cible' est une constante : elle ne peut pas être saisie au clavier.", node.anchor);
        } else if (type.estTableau) {
          _erreur(
            "'$cible' est un tableau : indiquez la case à remplir, par exemple $cible[1].",
            node.anchor,
          );
        }
      }
      return TypeSenAlgo.inconnu;
    }

    if (nomMinuscule == 'abs') {
      final t = node.arguments.isEmpty ? TypeSenAlgo.inconnu : node.arguments.first.accept(this);
      if (t.estConnu && !t.estNumerique) {
        _erreur("'abs' s'applique à un nombre, pas à ${_article(t)}.", node.anchor);
      }
      return t.estNumerique ? t : TypeSenAlgo.inconnu;
    }

    if (nomMinuscule == 'racine' || nomMinuscule == 'sqrt') {
      final t = node.arguments.isEmpty ? TypeSenAlgo.inconnu : node.arguments.first.accept(this);
      if (t.estConnu && !t.estNumerique) {
        _erreur("'$nom' s'applique à un nombre, pas à ${_article(t)}.", node.anchor);
      }
      return TypeSenAlgo.reel;
    }

    // Accès à un tableau écrit avec des parenthèses : t(i).
    final variable = _portee.chercher(nom);
    if (variable != null && variable.estTableau) {
      if (node.arguments.length == 1) {
        _verifierIndice(node.arguments.first.accept(this), node.anchor);
      } else {
        _erreur("l'accès au tableau '$nom' demande exactement un indice.", node.anchor);
      }
      return TypeSenAlgo(variable.element);
    }

    final signature = _signatures[nom];
    if (signature == null) {
      for (final a in node.arguments) {
        a.accept(this);
      }
      _erreur("'$nom' n'est ni une fonction, ni une procédure, ni un tableau connu.", node.anchor);
      return TypeSenAlgo.inconnu;
    }

    if (node.arguments.length != signature.parametres.length) {
      _erreur(
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
          _severitePour(attendu, typeArg),
        );
      }
      // Un paramètre de sortie doit recevoir quelque chose où écrire.
      if (p.mode != ParamMode.donnee) {
        final arg = node.arguments[i];
        if (arg is! VariableNode && arg is! ArrayAccessNode) {
          _erreur(
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
