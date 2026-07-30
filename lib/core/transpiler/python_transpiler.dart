import '../ast/ast.dart';
import '../lexer/token.dart';

/// Traduit un programme SenAlgo (AST) en code Python équivalent.
/// Limites connues (documentées plutôt que cachées) :
/// - Les paramètres "résultat"/"donnée-résultat" sont simulés par des
///   valeurs de retour multiples (idiome Python standard). Lorsqu'un tel
///   appel apparaît au milieu d'une expression, il est remonté avant
///   l'instruction dans une variable temporaire, l'affectation multiple ne
///   pouvant pas s'écrire à l'intérieur d'une expression Python.
/// - Le décalage d'indice des tableaux (bornes personnalisées, ex:
///   tableau(1:20)) est géré symboliquement à partir de la borne connue au
///   moment de la déclaration ; si une borne ne peut pas être déterminée
///   (tableau paramètre sans bornes explicites), on suppose un indice déjà
///   basé sur 0.
class PythonTranspiler implements ASTVisitor<String> {
  final StringBuffer _out = StringBuffer();
  int _indentLevel = 0;

  /// Nom de tableau -> expression Python de sa borne inférieure.
  final Map<String, String> _arrayLowerBounds = {};
  final Set<String> _knownArrays = {};
  final Map<String, String> _varTypes = {};
  final Map<String, List<Parameter>> _subroutineParams = {};
  final List<List<String>> _outParamStack = [];

  /// Noms des sous-programmes qui renvoient une valeur (fonctions), par
  /// opposition aux procédures. Une fonction dotée de paramètres de sortie
  /// renvoie en Python un tuple `(valeur, sortie1, …)` : il faut donc une
  /// cible supplémentaire pour la valeur de retour.
  final Set<String> _functionNames = {};

  /// Lignes à émettre juste avant l'instruction en cours.
  ///
  /// Un appel doté de paramètres `résultat` se traduit par une affectation
  /// multiple, qui ne peut pas s'écrire au milieu d'une expression Python. On
  /// le remonte donc dans une variable temporaire, et l'expression n'utilise
  /// plus que cette variable.
  final List<String> _prelude = [];
  int _tempCounter = 0;

  /// Émet les lignes remontées, à l'indentation courante, puis vide le tampon.
  void _emitPrelude() {
    if (_prelude.isEmpty) return;
    final lignes = List<String>.from(_prelude);
    _prelude.clear();
    for (final l in lignes) {
      _line(l);
    }
  }

  /// Retire et renvoie les lignes remontées sans les émettre, pour les placer
  /// à un endroit choisi (corps de boucle, branche `else`…).
  List<String> _takePrelude() {
    final lignes = List<String>.from(_prelude);
    _prelude.clear();
    return lignes;
  }

  /// Indices des paramètres de sortie de [callee], vide si l'appel n'en a pas.
  List<int> _outIndices(String callee, int argCount) {
    final params = _subroutineParams[callee];
    if (params == null) return const [];
    final indices = <int>[];
    for (int i = 0; i < params.length && i < argCount; i++) {
      if (params[i].mode != ParamMode.donnee) indices.add(i);
    }
    return indices;
  }

  /// Convertit tout le programme. Utiliser une NOUVELLE instance de
  /// [PythonTranspiler] à chaque appel (l'état interne n'est pas réinitialisé).
  String transpile(ProgramNode program) {
    return program.accept(this);
  }

  String _ind() => ''.padLeft(_indentLevel * 4);
  void _line(String s) => _out.writeln('${_ind()}$s');

  String _pyDefaultForType(String type) {
    var t = type.toLowerCase().trim();
    if (t.endsWith('s')) t = t.substring(0, t.length - 1);
    switch (t) {
      case 'entier': return '0';
      case 'reel':
      case 'réel': return '0.0';
      case 'booleen':
      case 'booléen': return 'False';
      case 'chaine':
      case 'chaîne':
      case 'caractere':
      case 'caractère': return "''";
      default: return 'None';
    }
  }

  String _castForType(String? type) {
    var t = (type ?? '').toLowerCase().trim();
    if (t.endsWith('s')) t = t.substring(0, t.length - 1);
    switch (t) {
      case 'entier': return 'int';
      case 'reel':
      case 'réel': return 'float';
      case 'booleen':
      case 'booléen': return '_lire_booleen';
      default: return 'str';
    }
  }

  String _shiftedIndex(String arrayName, String indexPy) {
    final lower = _arrayLowerBounds[arrayName];
    if (lower == null) return indexPy;
    return '($indexPy) - ($lower)';
  }

  String _pyName(String name) => name;

  @override
  String visitProgram(ProgramNode node) {
    _out.writeln('# Code Python généré automatiquement à partir d\'un programme');
    _out.writeln('# SenAlgo. Relis-le : les tableaux à bornes personnalisées');
    _out.writeln('# peuvent encore nécessiter un ajustement manuel.');
    _out.writeln('import math');
    _out.writeln();
    _out.writeln('def _lire_booleen(s):');
    _out.writeln("    return s.strip().lower() in ('vrai', 'true', '1')");
    _out.writeln();

    for (final decl in node.declarations) {
      if (decl is FunctionDeclarationNode) {
        _subroutineParams[decl.name] = decl.parameters;
        _functionNames.add(decl.name);
      } else if (decl is ProcedureDeclarationNode) {
        _subroutineParams[decl.name] = decl.parameters;
      }
    }

    final topLevelDecls = <ASTNode>[];
    for (final decl in node.declarations) {
      if (decl is FunctionDeclarationNode || decl is ProcedureDeclarationNode) {
        decl.accept(this);
        _out.writeln();
      } else {
        topLevelDecls.add(decl);
      }
    }

    _out.writeln('def main():');
    _indentLevel++;
    if (topLevelDecls.isEmpty && node.body.statements.isEmpty) {
      _line('pass');
    }
    for (final d in topLevelDecls) {
      d.accept(this);
    }
    node.body.accept(this);
    _indentLevel--;
    _out.writeln();
    _out.writeln('if __name__ == "__main__":');
    _out.writeln('    main()');
    return _out.toString();
  }

  @override
  String visitBlock(BlockNode node) {
    if (node.statements.isEmpty) {
      _line('pass');
      return '';
    }
    for (final s in node.statements) {
      s.accept(this);
    }
    return '';
  }

  @override
  String visitVarDeclaration(VarDeclarationNode node) {
    for (final id in node.identifiers) {
      _varTypes[id] = node.type;
      _line('$id = ${_pyDefaultForType(node.type)}');
    }
    return '';
  }

  @override
  String visitConstDeclaration(ConstDeclarationNode node) {
    final valeur = node.value.accept(this);
    _emitPrelude();
    _line('${node.identifier} = $valeur');
    return '';
  }

  @override
  String visitTypeDeclaration(TypeDeclarationNode node) {
    _line('# TYPE ${node.identifier} : non traduit automatiquement');
    return '';
  }

  @override
  String visitArrayDeclaration(ArrayDeclarationNode node) {
    final lowerPy = node.lowerBound.accept(this);
    final upperPy = node.upperBound.accept(this);
    final defaultVal = _pyDefaultForType(node.baseType);
    for (final id in node.identifiers) {
      _arrayLowerBounds[id] = lowerPy;
      _knownArrays.add(id);
      _varTypes[id] = node.baseType;
      _line('$id = [$defaultVal] * ((($upperPy) - ($lowerPy)) + 1)');
    }
    return '';
  }

  @override
  String visitAssignment(AssignmentNode node) {
    final valeur = node.value.accept(this);
    _emitPrelude();
    _line('${node.identifier} = $valeur');
    return '';
  }

  @override
  String visitArrayAssignment(ArrayAssignmentNode node) {
    final idxPy = _shiftedIndex(node.identifier, node.index.accept(this));
    final valeur = node.value.accept(this);
    _emitPrelude();
    _line('${node.identifier}[$idxPy] = $valeur');
    return '';
  }

  @override
  String visitIf(IfNode node) {
    final conditionPy = node.condition.accept(this);
    _emitPrelude();
    _line('if $conditionPy:');
    _indentLevel++;
    node.thenBranch.accept(this);
    _indentLevel--;
    int niveauxImbriques = 0;
    for (final elseIf in node.elseIfs) {
      final condPy = elseIf.condition.accept(this);
      final remontees = _takePrelude();
      if (remontees.isEmpty) {
        _line('elif $condPy:');
        _indentLevel++;
        elseIf.body.accept(this);
        _indentLevel--;
        continue;
      }
      // Un « elif » ne peut pas etre precede d'instructions. On ouvre donc un
      // « else » et on imbrique : l'appel remonte n'a lieu que si les cas
      // precedents ont echoue, comme dans le programme source.
      _line('else:');
      _indentLevel++;
      niveauxImbriques++;
      for (final l in remontees) {
        _line(l);
      }
      _line('if $condPy:');
      _indentLevel++;
      elseIf.body.accept(this);
      _indentLevel--;
    }
    if (node.elseBranch != null) {
      _line('else:');
      _indentLevel++;
      node.elseBranch!.accept(this);
      _indentLevel--;
    }
    _indentLevel -= niveauxImbriques;
    return '';
  }

  @override
  String visitWhile(WhileNode node) {
    final conditionPy = node.condition.accept(this);
    final remontees = _takePrelude();
    if (remontees.isEmpty) {
      _line('while $conditionPy:');
      _indentLevel++;
      node.body.accept(this);
      _indentLevel--;
      return '';
    }
    // La condition contient un appel remonte, qui doit etre reevalue a chaque
    // tour : on ne peut donc pas le placer avant la boucle. On passe par une
    // boucle infinie avec sortie explicite, strictement equivalente.
    _line('while True:');
    _indentLevel++;
    for (final l in remontees) {
      _line(l);
    }
    _line('if not ($conditionPy):');
    _indentLevel++;
    _line('break');
    _indentLevel--;
    node.body.accept(this);
    _indentLevel--;
    return '';
  }

  @override
  String visitFor(ForNode node) {
    final startPy = node.startValue.accept(this);
    final endPy = node.endValue.accept(this);
    final stepPy = node.step != null ? node.step!.accept(this) : '1';
    final stepVar = '_pas_${node.identifier}';
    _emitPrelude();
    _line('$stepVar = $stepPy');
    _line('for ${node.identifier} in range($startPy, ($endPy) + (1 if $stepVar > 0 else -1), $stepVar):');
    _indentLevel++;
    node.body.accept(this);
    _indentLevel--;
    return '';
  }

  @override
  String visitRepeat(RepeatNode node) {
    _line('while True:');
    _indentLevel++;
    node.body.accept(this);
    final conditionPy = node.condition.accept(this);
    // La condition est evaluee en fin de tour : les lignes remontees se
    // placent naturellement juste avant le test, a l'interieur de la boucle.
    _emitPrelude();
    _line('if $conditionPy:');
    _indentLevel++;
    _line('break');
    _indentLevel--;
    _indentLevel--;
    return '';
  }

  @override
  String visitSelon(SelonNode node) {
    if (node.cases.isEmpty) {
      if (node.defaultBranch != null) node.defaultBranch!.accept(this);
      return '';
    }
    bool first = true;
    for (final c in node.cases) {
      _line('${first ? 'if' : 'elif'} ${c.guard.accept(this)}:');
      _indentLevel++;
      c.body.accept(this);
      _indentLevel--;
      first = false;
    }
    if (node.defaultBranch != null) {
      _line('else:');
      _indentLevel++;
      node.defaultBranch!.accept(this);
      _indentLevel--;
    }
    return '';
  }

  void _emitParamInits(List<Parameter> params) {
    for (final p in params) {
      if (p.isArray) {
        _knownArrays.add(p.name);
        _varTypes[p.name] = p.baseType ?? '';
        if (p.lowerBound != null) {
          _arrayLowerBounds[p.name] = p.lowerBound!.accept(this);
        }
      } else {
        _varTypes[p.name] = p.type;
      }
      if (p.mode == ParamMode.resultat) {
        if (p.isArray && p.lowerBound != null && p.upperBound != null) {
          final lowerPy = p.lowerBound!.accept(this);
          final upperPy = p.upperBound!.accept(this);
          final defaultVal = _pyDefaultForType(p.baseType ?? '');
          _line('${p.name} = [$defaultVal] * ((($upperPy) - ($lowerPy)) + 1)');
        } else {
          _line('${p.name} = ${_pyDefaultForType(p.type)}');
        }
      }
    }
  }

  @override
  String visitFunctionDeclaration(FunctionDeclarationNode node) {
    final paramNames = node.parameters.map((p) => p.name).join(', ');
    _line('def ${_pyName(node.name)}($paramNames):');
    _indentLevel++;
    _emitParamInits(node.parameters);
    for (final d in node.declarations) {
      d.accept(this);
    }
    final outParams = node.parameters.where((p) => p.mode != ParamMode.donnee).map((p) => p.name).toList();
    _outParamStack.add(outParams);
    node.body.accept(this);
    _outParamStack.removeLast();
    if (outParams.isNotEmpty) {
      _line('return ${outParams.join(', ')}  # valeur de retour manquante si aucun "Retourner" n\'a été exécuté');
    }
    _indentLevel--;
    _out.writeln();
    return '';
  }

  @override
  String visitProcedureDeclaration(ProcedureDeclarationNode node) {
    final paramNames = node.parameters.map((p) => p.name).join(', ');
    _line('def ${_pyName(node.name)}($paramNames):');
    _indentLevel++;
    _emitParamInits(node.parameters);
    for (final d in node.declarations) {
      d.accept(this);
    }
    final outParams = node.parameters.where((p) => p.mode != ParamMode.donnee).map((p) => p.name).toList();
    _outParamStack.add(outParams);
    node.body.accept(this);
    _outParamStack.removeLast();
    if (outParams.isNotEmpty) {
      _line('return ${outParams.join(', ')}');
    }
    _indentLevel--;
    _out.writeln();
    return '';
  }

  @override
  String visitReturn(ReturnNode node) {
    final outParams = _outParamStack.isNotEmpty ? _outParamStack.last : const <String>[];
    if (node.value != null) {
      final valuePy = node.value!.accept(this);
      _line(outParams.isEmpty ? 'return $valuePy' : 'return $valuePy, ${outParams.join(', ')}');
    } else {
      _line(outParams.isEmpty ? 'return' : 'return ${outParams.join(', ')}');
    }
    return '';
  }

  @override
  String visitExpressionStmt(ExpressionStmtNode node) {
    final expr = node.expression;
    if (expr is CallNode) {
      final calleeLower = expr.callee.toLowerCase();

      // Lire/Saisir en tant qu'instruction : "Lire x" => x = int(input()) etc.
      if ({'lire', 'saisir'}.contains(calleeLower) && expr.arguments.isNotEmpty) {
        final target = expr.arguments[0];
        if (target is VariableNode) {
          final castFn = _castForType(_varTypes[target.name.lexeme]);
          _line('${target.name.lexeme} = $castFn(input())');
        } else if (target is ArrayAccessNode) {
          final castFn = _castForType(_varTypes[target.name.lexeme]);
          final idxPy = _shiftedIndex(target.name.lexeme, target.index.accept(this));
          _emitPrelude();
          _line('${target.name.lexeme}[$idxPy] = $castFn(input())');
        }
        return '';
      }

      // Appel à une procédure/fonction connue avec paramètres résultat/donnée-résultat
      // => simulé par affectation multiple (idiome Python standard).
      final sorties = _outIndices(expr.callee, expr.arguments.length);
      if (sorties.isNotEmpty) {
        final cibles = sorties.map((i) => expr.arguments[i].accept(this)).toList();
        // Une fonction renvoie (valeur, sorties...) : il faut une cible de plus
        // pour la valeur de retour, ici inutilisée puisque l'appel est isolé.
        if (_functionNames.contains(expr.callee)) {
          cibles.insert(0, '_t${_tempCounter++}');
        }
        final appel = _renderCall(expr, commeInstruction: true);
        _emitPrelude();
        _line('${cibles.join(', ')} = $appel');
        return '';
      }
      final appel = _renderCall(expr, commeInstruction: true);
      _emitPrelude();
      _line(appel);
      return '';
    }
    final valeur = expr.accept(this);
    _emitPrelude();
    _line(valeur);
    return '';
  }

  /// Traduit un appel.
  ///
  /// [commeInstruction] indique que l'appel constitue à lui seul une
  /// instruction : l'affectation multiple des paramètres de sortie est alors
  /// gérée par [visitExpressionStmt], et il n'y a rien à remonter.
  String _renderCall(CallNode node, {bool commeInstruction = false}) {
    final calleeLower = node.callee.toLowerCase();

    // Appel doté de paramètres de sortie AU MILIEU d'une expression : on le
    // remonte avant l'instruction, sans quoi le tuple renvoyé par la fonction
    // Python se retrouverait utilisé comme une valeur ordinaire.
    if (!commeInstruction) {
      final sorties = _outIndices(node.callee, node.arguments.length);
      if (sorties.isNotEmpty) {
        final cibles = sorties.map((i) => node.arguments[i].accept(this)).toList();
        final argsPy = node.arguments.map((a) => a.accept(this)).join(', ');
        if (_functionNames.contains(node.callee)) {
          final temp = '_t${_tempCounter++}';
          _prelude.add('$temp, ${cibles.join(', ')} = ${node.callee}($argsPy)');
          return temp;
        }
        // Une procédure n'a pas de valeur : l'employer dans une expression est
        // une erreur du programme source, mais on garde l'effet de bord.
        _prelude.add('${cibles.join(', ')} = ${node.callee}($argsPy)');
        return 'None';
      }
    }

    if (_knownArrays.contains(node.callee) && node.arguments.length == 1) {
      final idxPy = node.arguments[0].accept(this);
      return '${node.callee}[${_shiftedIndex(node.callee, idxPy)}]';
    }
    if ({'ecrire', 'écrire', 'afficher'}.contains(calleeLower)) {
      if (node.arguments.isEmpty) return "print('', end='')";
      final parts = node.arguments.map((a) => 'str(${a.accept(this)})').join(' + ');
      return "print($parts, end='')";
    }
    if ({'ecrireln', 'écrireln', 'afficherln'}.contains(calleeLower)) {
      if (node.arguments.isEmpty) return 'print()';
      final parts = node.arguments.map((a) => 'str(${a.accept(this)})').join(' + ');
      return 'print($parts)';
    }
    if ({'lire', 'saisir'}.contains(calleeLower)) {
      return 'input()';
    }
    if (calleeLower == 'abs') return 'abs(${node.arguments[0].accept(this)})';
    if (calleeLower == 'racine' || calleeLower == 'sqrt') return 'math.sqrt(${node.arguments[0].accept(this)})';
    if (calleeLower == 'entier') return 'int(${node.arguments[0].accept(this)})';

    final argsPy = node.arguments.map((a) => a.accept(this)).join(', ');
    return '${node.callee}($argsPy)';
  }

  @override
  String visitCall(CallNode node) => _renderCall(node);

  @override
  String visitBinary(BinaryNode node) {
    final l = node.left.accept(this);
    final r = node.right.accept(this);
    String op;
    switch (node.operator.type) {
      case TokenType.PLUS: op = '+'; break;
      case TokenType.MOINS: op = '-'; break;
      case TokenType.FOIS: op = '*'; break;
      case TokenType.DIVISE: op = '/'; break;
      case TokenType.DIV: op = '//'; break;
      case TokenType.MOD: op = '%'; break;
      case TokenType.PUISSANCE: op = '**'; break;
      case TokenType.EGAL: op = '=='; break;
      case TokenType.DIFFERENT: op = '!='; break;
      case TokenType.PLUS_PETIT: op = '<'; break;
      case TokenType.PLUS_PETIT_EGAL: op = '<='; break;
      case TokenType.PLUS_GRAND: op = '>'; break;
      case TokenType.PLUS_GRAND_EGAL: op = '>='; break;
      case TokenType.ET: op = 'and'; break;
      case TokenType.OU: op = 'or'; break;
      default: op = '?';
    }
    return '($l $op $r)';
  }

  @override
  String visitUnary(UnaryNode node) {
    final rightPy = node.right.accept(this);
    switch (node.operator.type) {
      case TokenType.MOINS: return '(-($rightPy))';
      case TokenType.NON: return '(not ($rightPy))';
      default: return rightPy;
    }
  }

  @override
  String visitLiteral(LiteralNode node) {
    final v = node.value;
    if (v is String) {
      final escaped = v.replaceAll('\\', '\\\\').replaceAll("'", "\\'");
      return "'$escaped'";
    }
    if (v is bool) return v ? 'True' : 'False';
    if (v == null) return 'None';
    return '$v';
  }

  @override
  String visitVariable(VariableNode node) => node.name.lexeme;

  @override
  String visitArrayAccess(ArrayAccessNode node) {
    final idxPy = node.index.accept(this);
    return '${node.name.lexeme}[${_shiftedIndex(node.name.lexeme, idxPy)}]';
  }
}
