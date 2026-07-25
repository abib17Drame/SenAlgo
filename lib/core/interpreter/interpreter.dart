import '../ast/ast.dart';
import '../lexer/token.dart';
import 'environment.dart';
import 'dart:math' as math;

class Interpreter implements ASTVisitor<dynamic> {
  Environment environment = Environment();
  final Function(String) onPrint;
  final Future<String> Function() onRead;
  final Function(Map<String, dynamic>)? onVariableChanged;
  final Future<void> Function(ASTNode, String)? onStatement;

  Interpreter({required this.onPrint, required this.onRead, this.onVariableChanged, this.onStatement});

  /// Exécute le programme. Les erreurs d'exécution sont **propagées** à
  /// l'appelant (et non avalées ici) : c'est lui qui décide comment les
  /// présenter et qui met le statut d'exécution à jour. C'est aussi ce qui
  /// permet au signal d'arrêt du débogueur pas-à-pas de remonter intact.
  Future<void> interpret(ProgramNode program) async {
    try {
      for (var decl in program.declarations) { await _execute(decl); }
      await _execute(program.body);
    } on ReturnValue {
      // "Retourner" au niveau du programme principal : fin normale.
      return;
    }
  }

  Future<dynamic> _execute(ASTNode node) async {
    if (onStatement != null) {
      bool isInteresting = false;
      String explanation = "";
      if (node is AssignmentNode) {
        isInteresting = true;
        explanation = "Préparation de l'affectation pour la variable '${node.identifier}'...";
      } else if (node is IfNode) {
        isInteresting = true;
        explanation = "Évaluation de la condition SI...";
      } else if (node is WhileNode) {
        isInteresting = true;
        explanation = "Vérification de la condition de la boucle TANTQUE...";
      } else if (node is ForNode) {
        isInteresting = true;
        explanation = "Mise à jour de la boucle POUR (variable '${node.identifier}')...";
      } else if (node is RepeatNode) {
        isInteresting = true;
        explanation = "Vérification de la condition REPETER...JUSQU'A...";
      } else if (node is SelonNode) {
        isInteresting = true;
        explanation = "Évaluation des cas pour l'instruction SELON...";
      } else if (node is ExpressionStmtNode && node.expression is CallNode) {
        isInteresting = true;
        final callee = (node.expression as CallNode).callee;
        explanation = "Exécution de l'appel à '$callee'...";
      } else if (node is ArrayAssignmentNode) {
        isInteresting = true;
        explanation = "Affectation de l'élément dans le tableau '${node.identifier}'...";
      }

      if (isInteresting) {
        await onStatement!(node, explanation);
      }
    }
    return await node.accept(this);
  }
  Future<dynamic> _evaluate(ASTNode node) async => await node.accept(this);

  @override Future<dynamic> visitProgram(ProgramNode node) async => null;

  @override
  Future<dynamic> visitVarDeclaration(VarDeclarationNode node) async {
    for (var id in node.identifiers) {
      environment.define(id, _defaultForType(node.type), node.type);
    }
    onVariableChanged?.call(environment.getAllValues());
    return null;
  }

  @override
  Future<dynamic> visitConstDeclaration(ConstDeclarationNode node) async {
    final value = await _evaluate(node.value);
    environment.define(node.identifier, value, "constante");
    return null;
  }

  @override
  Future<dynamic> visitArrayDeclaration(ArrayDeclarationNode node) async {
    final lower = await _evaluate(node.lowerBound) as int;
    final upper = await _evaluate(node.upperBound) as int;
    final size = upper - lower + 1;
    if (size <= 0) throw "Taille de tableau invalide ($lower..$upper).";
    
    dynamic defaultValue;
    String cleanType = node.baseType.toLowerCase();
    // Support D'ENTIER, D' REEL, etc.
    if (cleanType.startsWith("'")) cleanType = cleanType.substring(1);
    if (cleanType.endsWith("'")) cleanType = cleanType.substring(0, cleanType.length - 1);
    cleanType = cleanType.trim();

    switch (cleanType) {
      case 'entier': defaultValue = 0; break;
      case 'reel': 
      case 'réel': defaultValue = 0.0; break;
      case 'booleen': 
      case 'booléen': defaultValue = false; break;
      case 'chaine': 
      case 'chaîne': defaultValue = ""; break;
      default: defaultValue = null;
    }
    
    for (final id in node.identifiers) {
      environment.define(id, ArrayData(lower: lower, upper: upper, values: List.filled(size, defaultValue), baseType: cleanType), "tableau");
    }
    onVariableChanged?.call(environment.getAllValues());
    return null;
  }

  @override
  Future<dynamic> visitArrayAssignment(ArrayAssignmentNode node) async {
    final array = environment.get(node.identifier);
    if (array is! ArrayData) throw "'${node.identifier}' n'est pas un tableau.";
    final index = await _evaluate(node.index) as int;
    if (index < array.lower || index > array.upper) throw "Index hors limites: $index (Taille: ${array.lower}..${array.upper})";
    final value = await _evaluate(node.value);
    array.values[index - array.lower] = value;
    onVariableChanged?.call(environment.getAllValues());
    return null;
  }

  @override
  Future<dynamic> visitArrayAccess(ArrayAccessNode node) async {
    final array = environment.get(node.name.lexeme);
    if (array is! ArrayData) throw "'${node.name.lexeme}' n'est pas un tableau.";
    final index = await _evaluate(node.index) as int;
    if (index < array.lower || index > array.upper) throw "Index hors limites: $index (Taille: ${array.lower}..${array.upper})";
    return array.values[index - array.lower];
  }

  @override Future<dynamic> visitTypeDeclaration(TypeDeclarationNode node) async => null;

  @override
  Future<dynamic> visitAssignment(AssignmentNode node) async {
    final value = await _evaluate(node.value);
    environment.assign(node.identifier, value);
    onVariableChanged?.call(environment.getAllValues());
    return value;
  }

  @override
  Future<dynamic> visitIf(IfNode node) async {
    if (_isTruthy(await _evaluate(node.condition))) {
      await _execute(node.thenBranch);
    } else {
      bool exec = false;
      for (var ei in node.elseIfs) {
        if (_isTruthy(await _evaluate(ei.condition))) { await _execute(ei.body); exec = true; break; }
      }
      if (!exec && node.elseBranch != null) await _execute(node.elseBranch!);
    }
    return null;
  }

  @override
  Future<dynamic> visitWhile(WhileNode node) async {
    while (_isTruthy(await _evaluate(node.condition))) { await _execute(node.body); }
    return null;
  }

  @override
  Future<dynamic> visitFor(ForNode node) async {
    final start = await _evaluate(node.startValue);
    final end = await _evaluate(node.endValue);
    final step = node.step != null ? await _evaluate(node.step!) : 1;
    environment.define(node.identifier, start, "entier");
    if (step > 0) {
      for (var i = start; i <= end; i += step) { environment.assign(node.identifier, i); await _execute(node.body); }
    } else {
      for (var i = start; i >= end; i += step) { environment.assign(node.identifier, i); await _execute(node.body); }
    }
    return null;
  }

  @override
  Future<dynamic> visitRepeat(RepeatNode node) async {
    do { await _execute(node.body); } while (!_isTruthy(await _evaluate(node.condition)));
    return null;
  }

  @override
  Future<dynamic> visitSelon(SelonNode node) async {
    for (final c in node.cases) {
      if (_isTruthy(await _evaluate(c.guard))) {
        await _execute(c.body);
        return null;
      }
    }
    if (node.defaultBranch != null) await _execute(node.defaultBranch!);
    return null;
  }

  @override
  Future<dynamic> visitFunctionDeclaration(FunctionDeclarationNode node) async {
    final function = SenAlgoFunction(node, environment);
    environment.defineSubroutine(node.name, function);
    return null;
  }

  @override
  Future<dynamic> visitProcedureDeclaration(ProcedureDeclarationNode node) async {
    final procedure = SenAlgoProcedure(node, environment);
    environment.defineSubroutine(node.name, procedure);
    return null;
  }

  @override
  Future<dynamic> visitCall(CallNode node) async {
    final calleeLower = node.callee.toLowerCase();
    const builtins = {
      'ecrire', 'écrire', 'afficher', 'ecrireln', 'écrireln', 'afficherln',
      'lire', 'saisir', 'abs', 'racine', 'sqrt', 'entier',
    };

    if (builtins.contains(calleeLower)) {
      final List<dynamic> args = [];
      for (var arg in node.arguments) {
        args.add(await _evaluate(arg));
      }
      switch (calleeLower) {
        case 'ecrire':
        case 'écrire':
        case 'afficher':
          onPrint(args.join(""));
          return null;
        case 'ecrireln':
        case 'écrireln':
        case 'afficherln':
          onPrint("${args.join("")}\n");
          return null;
        case 'lire':
        case 'saisir':
          final input = await onRead();
          if (node.arguments.isNotEmpty) {
            final firstArg = node.arguments[0];
            if (firstArg is VariableNode) {
              final varName = firstArg.name.lexeme;
              final targetType = _getVariableType(varName);
              final castedValue = _cast(input, targetType);
              environment.assign(varName, castedValue);
              onVariableChanged?.call(environment.getAllValues());
              return castedValue;
            } else if (firstArg is ArrayAccessNode) {
              final array = environment.get(firstArg.name.lexeme);
              if (array is! ArrayData) throw "'${firstArg.name.lexeme}' n'est pas un tableau.";
              final index = await _evaluate(firstArg.index) as int;
              if (index < array.lower || index > array.upper) throw "Index hors limites: $index";
              final castedValue = _cast(input, array.baseType);
              array.values[index - array.lower] = castedValue;
              onVariableChanged?.call(environment.getAllValues());
              return castedValue;
            }
          }
          return input;
        case 'abs':
          return (args[0] as num).abs();
        case 'racine':
        case 'sqrt':
          return math.sqrt(args[0] as num);
        case 'entier':
          if (args.isEmpty) return 0;
          if (args[0] is String) return int.tryParse(args[0]) ?? 0;
          return (args[0] as num).toInt();
      }
    }

    final subroutine = environment.getSubroutine(node.callee);
    if (subroutine is SenAlgoCallable) {
      return await subroutine.call(this, node.arguments);
    }

    // Try array access with parentheses: t(i)
    try {
      final potentialArray = environment.get(node.callee);
      if (potentialArray is ArrayData) {
        if (node.arguments.length != 1) throw "L'accès au tableau '${node.callee}' nécessite un index.";
        final index = await _evaluate(node.arguments[0]) as int;
        if (index < potentialArray.lower || index > potentialArray.upper) {
          throw "Index hors limites: $index (Tableau: ${potentialArray.lower}..${potentialArray.upper})";
        }
        return potentialArray.values[index - potentialArray.lower];
      }
    } catch (e) {
      if (e is String && e.contains("indéfinie")) {
          // It's not an array, and it's not a subroutine, so we throw the error below
      } else {
        rethrow;
      }
    }

    throw "Fonction ou tableau inconnu : ${node.callee}";
  }

  @override
  Future<dynamic> visitReturn(ReturnNode node) async {
    final val = node.value != null ? await _evaluate(node.value!) : null;
    throw ReturnValue(val);
  }

  @override
  Future<dynamic> visitBinary(BinaryNode node) async {
    final l = await _evaluate(node.left);
    final r = await _evaluate(node.right);
    switch (node.operator.type) {
      case TokenType.PLUS: return (l is String || r is String) ? l.toString() + r.toString() : l + r;
      case TokenType.MOINS: return l - r;
      case TokenType.FOIS: return l * r;
      case TokenType.DIVISE: return l / r;
      case TokenType.DIV: return l ~/ r;
      case TokenType.MOD: return l % r;
      case TokenType.PLUS_GRAND: return l > r;
      case TokenType.PLUS_GRAND_EGAL: return l >= r;
      case TokenType.PLUS_PETIT: return l < r;
      case TokenType.PLUS_PETIT_EGAL: return l <= r;
      case TokenType.EGAL: return l == r;
      case TokenType.DIFFERENT: return l != r;
      case TokenType.ET: return l && r;
      case TokenType.OU: return l || r;
      default: return null;
    }
  }

  @override
  Future<dynamic> visitUnary(UnaryNode node) async {
    final r = await _evaluate(node.right);
    switch (node.operator.type) {
      case TokenType.MOINS: return -r;
      case TokenType.NON: return !_isTruthy(r);
      default: return null;
    }
  }

  @override Future<dynamic> visitLiteral(LiteralNode node) async => node.value;
  @override Future<dynamic> visitVariable(VariableNode node) async => environment.get(node.name.lexeme);

  @override
  Future<dynamic> visitBlock(BlockNode node) async {
    final prev = environment; environment = Environment(enclosing: prev);
    try { for (var s in node.statements) { await _execute(s); } } finally { environment = prev; }
    return null;
  }

  @override Future<dynamic> visitExpressionStmt(ExpressionStmtNode node) async { await _evaluate(node.expression); return null; }

  bool _isTruthy(dynamic obj) { if (obj == null) return false; if (obj is bool) return obj; return true; }

  String _getVariableType(String name) => environment.getType(name);

  /// Valeur par défaut pour un type déclaré (utilisé pour VARIABLES et pour
  /// initialiser un paramètre "résultat" avant l'exécution de la procédure).
  /// Normalise aussi les formes au pluriel ("réels", "entiers", "chaines")
  /// utilisées dans "tableau de X" / "tableau d'X".
  dynamic _defaultForType(String type) {
    var t = type.toLowerCase().trim();
    if (t.startsWith("'")) t = t.substring(1);
    if (t.endsWith("'")) t = t.substring(0, t.length - 1);
    t = t.trim();
    if (t.endsWith('s')) t = t.substring(0, t.length - 1);
    switch (t) {
      case 'entier': return 0;
      case 'reel':
      case 'réel': return 0.0;
      case 'chaine':
      case 'chaîne': return "";
      case 'booleen':
      case 'booléen': return false;
      case 'caractere':
      case 'caractère': return "";
      default: return null;
    }
  }

  /// Recopie la valeur finale d'un paramètre "résultat"/"donnée-résultat"
  /// vers l'argument réel passé par l'appelant (doit être une variable ou un
  /// élément de tableau).
  Future<void> _writeBackParam(ASTNode argumentNode, dynamic value) async {
    if (argumentNode is VariableNode) {
      environment.assign(argumentNode.name.lexeme, value);
      onVariableChanged?.call(environment.getAllValues());
    } else if (argumentNode is ArrayAccessNode) {
      final array = environment.get(argumentNode.name.lexeme);
      if (array is ArrayData) {
        final index = await _evaluate(argumentNode.index) as int;
        if (index >= array.lower && index <= array.upper) {
          array.values[index - array.lower] = value;
          onVariableChanged?.call(environment.getAllValues());
        }
      }
    } else {
      throw "Un paramètre 'résultat' ou 'donnée-résultat' doit recevoir une variable (ou un élément de tableau), pas une expression.";
    }
  }

  dynamic _cast(String value, String type) {
    switch (type.toLowerCase()) {
      case 'entier':
        return int.tryParse(value) ?? 0;
      case 'reel':
      case 'réel':
        return double.tryParse(value.replaceAll(',', '.')) ?? 0.0;
      case 'booleen':
      case 'booléen':
        return value.toLowerCase() == 'vrai' || value.toLowerCase() == 'true';
      case 'caractere':
      case 'caractère':
        return value.isNotEmpty ? value[0] : '';
      case 'chaine':
      case 'chaîne':
      default:
        return value;
    }
  }
}

class ReturnValue {
  final dynamic value;
  ReturnValue(this.value);
}

class ArrayData {
  final int lower;
  final int upper;
  final List<dynamic> values;
  final String baseType;
  ArrayData({required this.lower, required this.upper, required this.values, required this.baseType});

  @override
  String toString() => values.toString();
}

abstract class SenAlgoCallable {
  /// [argumentNodes] : les nœuds AST bruts des arguments (et non leur valeur
  /// déjà évaluée), afin de pouvoir recopier la valeur finale des paramètres
  /// "résultat"/"donnée-résultat" vers la variable réelle de l'appelant.
  Future<dynamic> call(Interpreter interpreter, List<ASTNode> argumentNodes);
}

/// Prépare l'environnement d'un appel (fonction ou procédure) : évalue les
/// arguments "donnée"/"donnée-résultat" dans l'environnement de l'appelant,
/// initialise les paramètres "résultat" à leur valeur par défaut, définit les
/// déclarations locales, exécute le corps, puis recopie la valeur finale des
/// paramètres de sortie vers les variables réelles de l'appelant.
/// Renvoie la valeur de retour (via ReturnValue), ou null.
Future<dynamic> _callSubroutine({
  required Interpreter interpreter,
  required List<Parameter> parameters,
  required List<ASTNode> declarations,
  required BlockNode body,
  required Environment closure,
  required List<ASTNode> argumentNodes,
}) async {
  if (argumentNodes.length != parameters.length) {
    throw "Nombre d'arguments incorrect : ${parameters.length} attendu(s), ${argumentNodes.length} fourni(s).";
  }

  final previousEnv = interpreter.environment;
  final env = Environment(enclosing: closure);

  // 1) Évaluer les arguments dans l'environnement de l'APPELANT avant de
  //    changer de portée, puis définir les paramètres dans le nouvel
  //    environnement.
  for (int i = 0; i < parameters.length; i++) {
    final p = parameters[i];
    dynamic initialValue;
    if (p.mode == ParamMode.resultat) {
      if (p.isArray && p.lowerBound != null && p.upperBound != null) {
        // Paramètre tableau "résultat" : on crée
        // un tableau neuf avec les bornes déclarées dans la signature.
        interpreter.environment = previousEnv;
        final lower = await interpreter._evaluate(p.lowerBound!) as int;
        final upper = await interpreter._evaluate(p.upperBound!) as int;
        final size = upper - lower + 1;
        final defaultVal = interpreter._defaultForType(p.baseType ?? '');
        initialValue = ArrayData(lower: lower, upper: upper, values: List.filled(size < 0 ? 0 : size, defaultVal), baseType: (p.baseType ?? '').toLowerCase().trim());
      } else {
        initialValue = interpreter._defaultForType(p.type);
      }
    } else {
      // donnée ou donnée-résultat : on lit la valeur réelle fournie par l'appelant
      interpreter.environment = previousEnv;
      initialValue = await interpreter._evaluate(argumentNodes[i]);
    }
    env.define(p.name, initialValue, p.type);
  }

  interpreter.environment = env;
  for (var decl in declarations) {
    await interpreter._execute(decl);
  }

  dynamic returnVal;
  try {
    await interpreter._execute(body);
  } catch (rv) {
    if (rv is ReturnValue) {
      returnVal = rv.value;
    } else {
      interpreter.environment = previousEnv;
      rethrow;
    }
  }

  // 2) Récupérer la valeur finale des paramètres résultat/donnée-résultat
  //    AVANT de quitter la portée de l'appel.
  final List<MapEntry<ASTNode, dynamic>> outputs = [];
  for (int i = 0; i < parameters.length; i++) {
    final p = parameters[i];
    if (p.mode != ParamMode.donnee) {
      outputs.add(MapEntry(argumentNodes[i], env.get(p.name)));
    }
  }

  interpreter.environment = previousEnv;

  // 3) Recopier vers les variables réelles de l'appelant.
  for (var entry in outputs) {
    await interpreter._writeBackParam(entry.key, entry.value);
  }

  return returnVal;
}

class SenAlgoFunction implements SenAlgoCallable {
  final FunctionDeclarationNode declaration;
  final Environment closure;

  SenAlgoFunction(this.declaration, this.closure);

  @override
  Future<dynamic> call(Interpreter interpreter, List<ASTNode> argumentNodes) {
    return _callSubroutine(
      interpreter: interpreter,
      parameters: declaration.parameters,
      declarations: declaration.declarations,
      body: declaration.body,
      closure: closure,
      argumentNodes: argumentNodes,
    );
  }
}

class SenAlgoProcedure implements SenAlgoCallable {
  final ProcedureDeclarationNode declaration;
  final Environment closure;

  SenAlgoProcedure(this.declaration, this.closure);

  @override
  Future<dynamic> call(Interpreter interpreter, List<ASTNode> argumentNodes) async {
    await _callSubroutine(
      interpreter: interpreter,
      parameters: declaration.parameters,
      declarations: declaration.declarations,
      body: declaration.body,
      closure: closure,
      argumentNodes: argumentNodes,
    );
    return null;
  }
}
