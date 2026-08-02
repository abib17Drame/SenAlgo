import '../ast/ast.dart';
import '../lexer/token.dart';
import 'environment.dart';
import 'dart:math' as math;

/// Signal levé lorsque l'utilisateur demande l'arrêt de l'exécution. Ce n'est
/// pas une erreur du programme : l'appelant le reconnaît et l'affiche comme un
/// arrêt volontaire plutôt que comme un échec.
const String kStoppedByUserSignal = "__SENALGO_STOPPED_BY_USER__";

class Interpreter implements ASTVisitor<dynamic> {
  Environment environment = Environment();
  final Function(String) onPrint;
  final Future<String> Function() onRead;
  final Function(Map<String, dynamic>)? onVariableChanged;
  final Future<void> Function(ASTNode, String)? onStatement;

  Interpreter({required this.onPrint, required this.onRead, this.onVariableChanged, this.onStatement});

  /// Passe à vrai quand [demanderArret] est appelé. Vérifié avant chaque
  /// instruction : c'est ce qui permet d'interrompre une boucle infinie.
  bool _arretDemande = false;

  /// Mesure le temps écoulé depuis la dernière fois que l'interpréteur a rendu
  /// la main à la boucle d'événements.
  final Stopwatch _chrono = Stopwatch();

  /// Durée maximale pendant laquelle l'interpréteur peut monopoliser le fil
  /// d'exécution. 16 ms correspond à une image à 60 par seconde : au-delà,
  /// l'interface commencerait à saccader.
  static const int _msMaxSansRespiration = 16;

  /// Demande l'arrêt de l'exécution en cours.
  ///
  /// L'arrêt n'est pas immédiat : il prend effet au prochain point de contrôle,
  /// c'est-à-dire avant la prochaine instruction. Appelable depuis l'interface
  /// pendant que le programme tourne.
  void demanderArret() => _arretDemande = true;

  /// Exécuté avant chaque instruction. Remplit deux rôles indissociables :
  ///
  /// - interrompre l'exécution si l'utilisateur l'a demandée ;
  /// - rendre périodiquement la main à la boucle d'événements de Flutter.
  ///
  /// Le second point est ce qui rend le premier possible. Les `await` de
  /// l'interpréteur portent presque toujours sur des valeurs déjà disponibles :
  /// ils passent par la file des **microtâches**, que Dart vide entièrement
  /// avant de rendre la main à l'interface. Une boucle infinie gèlerait donc
  /// l'application, et le clic sur « Arrêter » ne serait jamais traité.
  /// `Future.delayed(Duration.zero)` passe, lui, par la file des **événements**
  /// et laisse Flutter redessiner et traiter les clics.
  Future<void> _pointDeControle() async {
    if (_arretDemande) throw kStoppedByUserSignal;
    if (_chrono.elapsedMilliseconds < _msMaxSansRespiration) return;
    _chrono.reset();
    await Future<void>.delayed(Duration.zero);
    // L'utilisateur a pu cliquer sur « Arrêter » pendant cette respiration.
    if (_arretDemande) throw kStoppedByUserSignal;
  }

  /// Exécute le programme. Les erreurs d'exécution sont **propagées** à
  /// l'appelant (et non avalées ici) : c'est lui qui décide comment les
  /// présenter et qui met le statut d'exécution à jour. C'est aussi ce qui
  /// permet au signal d'arrêt du débogueur pas-à-pas de remonter intact.
  Future<void> interpret(ProgramNode program) async {
    _arretDemande = false;
    _chrono
      ..reset()
      ..start();
    try {
      for (var decl in program.declarations) { await _execute(decl); }
      await _execute(program.body);
    } on ReturnValue {
      // "Retourner" au niveau du programme principal : fin normale.
      return;
    }
  }

  Future<dynamic> _execute(ASTNode node) async {
    await _pointDeControle();
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
    final lower = _borne(await _evaluate(node.lowerBound), node.anchor?.line);
    final upper = _borne(await _evaluate(node.upperBound), node.anchor?.line);
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
    final index = _indice(await _evaluate(node.index), node.identifier, node.anchor?.line);
    if (index < array.lower || index > array.upper) throw "Index hors limites: $index (Taille: ${array.lower}..${array.upper})";
    final value = await _evaluate(node.value);
    array.values[index - array.lower] = _conformer(
      value,
      array.baseType,
      "'${node.identifier}[$index]'",
      node.anchor?.line,
    );
    onVariableChanged?.call(environment.getAllValues());
    return null;
  }

  /// Convertit une valeur d'indice en entier, ou refuse en français.
  ///
  /// Sans cela, un indice réel ou textuel remonte le message brut de Dart
  /// (« type 'String' is not a subtype of type 'int' in type cast »), qui
  /// n'apprend rien à qui écrit du pseudocode.
  /// Vérifie qu'une borne de boucle POUR est bien un entier.
  int _borneBoucle(dynamic valeur, String role, int? ligne) {
    if (valeur is int) return valeur;
    final suffixe = ligne != null ? " (ligne $ligne)" : "";
    throw "Dans un POUR, $role doit être un entier, or c'est ${_natureDe(valeur)}$suffixe.";
  }

  /// Convertit une borne de tableau en entier, ou refuse en français.
  int _borne(dynamic valeur, int? ligne) {
    if (valeur is int) return valeur;
    final suffixe = ligne != null ? " (ligne $ligne)" : "";
    throw "Les bornes d'un tableau doivent être des entiers, or l'une vaut ${_natureDe(valeur)}$suffixe.";
  }

  /// Vérifie qu'un argument de fonction intégrée est bien un nombre.
  num _nombre(dynamic valeur, String fonction, int? ligne) {
    if (valeur is num) return valeur;
    final suffixe = ligne != null ? " (ligne $ligne)" : "";
    throw "'$fonction' s'applique à un nombre, or on lui donne ${_natureDe(valeur)}$suffixe.";
  }

  int _indice(dynamic valeur, String nomTableau, int? ligne) {
    if (valeur is int) return valeur;
    final suffixe = ligne != null ? " (ligne $ligne)" : "";
    throw "L'indice de '$nomTableau' doit être un entier, or c'est ${_natureDe(valeur)}$suffixe.";
  }

  @override
  Future<dynamic> visitArrayAccess(ArrayAccessNode node) async {
    final array = environment.get(node.name.lexeme);
    if (array is! ArrayData) throw "'${node.name.lexeme}' n'est pas un tableau.";
    final index = _indice(await _evaluate(node.index), node.name.lexeme, node.name.line);
    if (index < array.lower || index > array.upper) throw "Index hors limites: $index (Taille: ${array.lower}..${array.upper})";
    return array.values[index - array.lower];
  }

  @override Future<dynamic> visitTypeDeclaration(TypeDeclarationNode node) async => null;

  @override
  Future<dynamic> visitAssignment(AssignmentNode node) async {
    final value = await _evaluate(node.value);
    final type = environment.getType(node.identifier);
    if (type == "constante") {
      throw "'${node.identifier}' est une constante : sa valeur ne peut pas changer"
          "${node.anchor != null ? " (ligne ${node.anchor!.line})" : ""}.";
    }
    final conforme = _conformer(value, type, "'${node.identifier}'", node.anchor?.line);
    environment.assign(node.identifier, conforme);
    onVariableChanged?.call(environment.getAllValues());
    return conforme;
  }

  @override
  Future<dynamic> visitIf(IfNode node) async {
    if (_condition(await _evaluate(node.condition), "d'un SI", node.anchor?.line)) {
      await _execute(node.thenBranch);
    } else {
      bool exec = false;
      for (var ei in node.elseIfs) {
        if (_condition(await _evaluate(ei.condition), "d'un SINONSI", node.anchor?.line)) { await _execute(ei.body); exec = true; break; }
      }
      if (!exec && node.elseBranch != null) await _execute(node.elseBranch!);
    }
    return null;
  }

  @override
  Future<dynamic> visitWhile(WhileNode node) async {
    while (_condition(await _evaluate(node.condition), "d'un TANT QUE", node.anchor?.line)) { await _execute(node.body); }
    return null;
  }

  @override
  Future<dynamic> visitFor(ForNode node) async {
    final ligne = node.anchor?.line;
    final start = _borneBoucle(await _evaluate(node.startValue), 'la valeur de départ', ligne);
    final end = _borneBoucle(await _evaluate(node.endValue), "la valeur d'arrivée", ligne);
    final step = node.step != null
        ? _borneBoucle(await _evaluate(node.step!), 'le pas', ligne)
        : 1;
    // Un pas nul ne boucle pas à l'infini ici (la condition de sortie est
    // fausse d'emblée), il ne fait rien du tout : le signaler vaut mieux que
    // de laisser croire que le corps a tourné.
    if (step == 0) {
      throw "Le pas d'un POUR ne peut pas être nul${ligne != null ? " (ligne $ligne)" : ""}.";
    }
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
    do { await _execute(node.body); } while (!_condition(await _evaluate(node.condition), "d'un JUSQU'À", node.anchor?.line));
    return null;
  }

  @override
  Future<dynamic> visitSelon(SelonNode node) async {
    for (final c in node.cases) {
      if (_condition(await _evaluate(c.guard), "d'un cas de SELON", node.anchor?.line)) {
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
              if (targetType == "constante") {
                throw "'$varName' est une constante : elle ne peut pas être saisie au clavier"
                    "${node.anchor != null ? " (ligne ${node.anchor!.line})" : ""}.";
              }
              if (_typeCanonique(targetType) == 'tableau') {
                throw "'$varName' est un tableau : indiquez la case à remplir, "
                    "par exemple $varName[1]${node.anchor != null ? " (ligne ${node.anchor!.line})" : ""}.";
              }
              final castedValue = _cast(input, targetType, varName, node.anchor?.line);
              environment.assign(varName, castedValue);
              onVariableChanged?.call(environment.getAllValues());
              return castedValue;
            } else if (firstArg is ArrayAccessNode) {
              final array = environment.get(firstArg.name.lexeme);
              if (array is! ArrayData) throw "'${firstArg.name.lexeme}' n'est pas un tableau.";
              final index = _indice(await _evaluate(firstArg.index), firstArg.name.lexeme, firstArg.name.line);
              if (index < array.lower || index > array.upper) throw "Index hors limites: $index";
              final castedValue = _cast(input, array.baseType, "${firstArg.name.lexeme}[$index]", firstArg.name.line);
              array.values[index - array.lower] = castedValue;
              onVariableChanged?.call(environment.getAllValues());
              return castedValue;
            }
          }
          return input;
        case 'abs':
          return _nombre(args.isEmpty ? null : args[0], 'abs', node.anchor?.line).abs();
        case 'racine':
        case 'sqrt':
          final sous = _nombre(args.isEmpty ? null : args[0], calleeLower, node.anchor?.line);
          if (sous < 0) {
            throw "Racine carrée d'un nombre négatif ($sous)"
                "${node.anchor != null ? " (ligne ${node.anchor!.line})" : ""}.";
          }
          return math.sqrt(sous);
        case 'entier':
          if (args.isEmpty) return 0;
          if (args[0] is String) return int.tryParse(args[0]) ?? 0;
          return _nombre(args[0], 'entier', node.anchor?.line).toInt();
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
        final index = _indice(await _evaluate(node.arguments[0]), node.callee, node.anchor?.line);
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
    final op = node.operator;
    switch (op.type) {
      // Le '+' concatène dès qu'un des deux côtés est textuel, sinon il ajoute.
      case TokenType.PLUS:
        if (l is String || r is String) return l.toString() + r.toString();
        return _operande(l, op) + _operande(r, op);
      case TokenType.MOINS: return _operande(l, op) - _operande(r, op);
      case TokenType.FOIS: return _operande(l, op) * _operande(r, op);
      // Sans ces trois contrôles, Dart renvoie `Infinity` pour `5/0` et lève
      // une exception en anglais pour `5 mod 0`.
      case TokenType.DIVISE:
        if (r == 0) throw "Division par zéro (ligne ${op.line}).";
        return _operande(l, op) / _operande(r, op);
      case TokenType.DIV:
        if (r == 0) throw "Division entière par zéro (ligne ${op.line}).";
        return _entierOperande(l, op) ~/ _entierOperande(r, op);
      case TokenType.MOD:
        if (r == 0) throw "Modulo par zéro (ligne ${op.line}).";
        return _entierOperande(l, op) % _entierOperande(r, op);
      case TokenType.PUISSANCE:
        final puissance = math.pow(_operande(l, op), _operande(r, op));
        // `pow` renvoie un num : on reste sur un entier quand les deux
        // opérandes le sont, pour que 2^3 affiche 8 et non 8.0.
        return (l is int && r is int && r >= 0) ? puissance.toInt() : puissance;
      case TokenType.PLUS_GRAND: return _comparer(l, r, op) > 0;
      case TokenType.PLUS_GRAND_EGAL: return _comparer(l, r, op) >= 0;
      case TokenType.PLUS_PETIT: return _comparer(l, r, op) < 0;
      case TokenType.PLUS_PETIT_EGAL: return _comparer(l, r, op) <= 0;
      case TokenType.EGAL: return l == r;
      case TokenType.DIFFERENT: return l != r;
      // Les deux côtés sont contrôlés avant d'être combinés : `&&` et `||`
      // court-circuitent, et laisseraient passer `faux ET 5` sans un mot.
      case TokenType.ET:
      case TokenType.OU:
        final gauche = _condition(l, "à gauche de '${op.lexeme}'", op.line);
        final droite = _condition(r, "à droite de '${op.lexeme}'", op.line);
        return op.type == TokenType.ET ? (gauche && droite) : (gauche || droite);
      default: return null;
    }
  }

  /// Vérifie qu'un opérande d'une opération arithmétique est bien un nombre.
  num _operande(dynamic valeur, Token op) {
    if (valeur is num) return valeur;
    throw "'${op.lexeme}' s'applique à des nombres, or on lui donne ${_natureDe(valeur)} (ligne ${op.line}).";
  }

  /// Idem pour `DIV` et `MOD`, qui exigent des entiers des deux côtés.
  int _entierOperande(dynamic valeur, Token op) {
    if (valeur is int) return valeur;
    throw "'${op.lexeme}' s'applique à des entiers, or on lui donne ${_natureDe(valeur)} (ligne ${op.line}).";
  }

  /// Compare deux valeurs pour `<`, `≤`, `>`, `≥`.
  ///
  /// Dart ne définit ces opérateurs que sur les nombres : sans ce détour,
  /// comparer deux chaînes, que l'analyse sémantique autorise pourtant,
  /// remonterait une erreur anglaise incompréhensible. L'ordre retenu pour
  /// les chaînes est l'ordre alphabétique.
  int _comparer(dynamic l, dynamic r, Token op) {
    if (l is num && r is num) return l.compareTo(r);
    if (l is String && r is String) return l.compareTo(r);
    throw "'${op.lexeme}' ne peut pas comparer ${_natureDe(l)} et ${_natureDe(r)} (ligne ${op.line}).";
  }

  @override
  Future<dynamic> visitUnary(UnaryNode node) async {
    final r = await _evaluate(node.right);
    switch (node.operator.type) {
      case TokenType.MOINS: return -r;
      case TokenType.NON: return !_condition(r, "de 'NON'", node.operator.line);
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

  /// Évalue la vérité d'une condition, en refusant tout ce qui n'est pas
  /// booléen.
  ///
  /// Le pseudocode n'a pas la convention « toute valeur non nulle vaut vrai »
  /// des langages de la famille C : une condition est vraie ou fausse, ou ce
  /// n'est pas une condition. L'accepter quand même ferait tourner sans broncher
  /// un `SI compteur ALORS` qui est presque toujours un `SI compteur > 0 ALORS`
  /// mal écrit.
  bool _condition(dynamic valeur, String contexte, int? ligne) {
    if (valeur is bool) return valeur;
    final suffixe = ligne != null ? " (ligne $ligne)" : "";
    throw "La condition $contexte doit être vraie ou fausse, or elle vaut ${_natureDe(valeur)}$suffixe.";
  }

  String _getVariableType(String name) => environment.getType(name);

  /// Valeur par défaut pour un type déclaré (utilisé pour VARIABLES et pour
  /// initialiser un paramètre "résultat" avant l'exécution de la procédure).
  /// Normalise aussi les formes au pluriel ("réels", "entiers", "chaines")
  /// utilisées dans "tableau de X" / "tableau d'X".
  /// Ramène un nom de type écrit dans le programme à sa forme canonique :
  /// sans accent, au singulier, débarrassé de l'apostrophe que le lexeur
  /// agglomère dans « tableau d'entiers ».
  static String _typeCanonique(String type) {
    var t = type.toLowerCase().trim();
    if (t.startsWith("d'")) t = t.substring(2);
    if (t.startsWith("'")) t = t.substring(1);
    if (t.endsWith("'")) t = t.substring(0, t.length - 1);
    t = t.trim();
    if (t.endsWith('s')) t = t.substring(0, t.length - 1);
    switch (t) {
      case 'réel':
        return 'reel';
      case 'booléen':
        return 'booleen';
      case 'caractère':
        return 'caractere';
      case 'chaîne':
        return 'chaine';
      default:
        return t;
    }
  }

  /// Décrit la nature d'une valeur, pour les messages d'erreur.
  static String _natureDe(dynamic v) {
    if (v is bool) return 'un booléen';
    if (v is int) return 'un entier';
    if (v is double) return 'un réel';
    if (v is ArrayData) return 'un tableau';
    if (v is String) return v.length == 1 ? 'un caractère' : 'une chaîne';
    return 'une valeur indéterminée';
  }

  /// Vérifie qu'une valeur peut entrer dans une case du type déclaré, et la
  /// renvoie éventuellement ajustée.
  ///
  /// C'est ici que la déclaration `n : entier` cesse d'être décorative. Le
  /// seul ajustement consenti est le rétrécissement `réel → entier`, que
  /// l'analyse sémantique a déjà annoncé par un avertissement : la partie
  /// décimale est réellement perdue, plutôt que la déclaration d'être ignorée.
  /// Tout autre mélange arrête le programme sur place.
  ///
  /// Un type que l'on ne reconnaît pas ne contraint rien : mieux vaut laisser
  /// passer que refuser un programme correct.
  dynamic _conformer(dynamic valeur, String typeDeclare, String cible, int? ligne) {
    if (valeur == null) return valeur;
    final suffixe = ligne != null ? " (ligne $ligne)" : "";

    switch (_typeCanonique(typeDeclare)) {
      case 'entier':
        if (valeur is int) return valeur;
        if (valeur is double) {
          if (valeur.isNaN || valeur.isInfinite) {
            throw "$cible est un entier, mais la valeur calculée n'est pas un nombre utilisable$suffixe.";
          }
          return valeur.truncate();
        }
        throw "$cible est un entier : impossible d'y mettre ${_natureDe(valeur)}$suffixe.";

      case 'reel':
        // Un entier est un réel parfaitement valide, et le laisser tel quel
        // évite d'afficher « 5.0 » là où l'utilisateur a écrit 5.
        if (valeur is num) return valeur;
        throw "$cible est un réel : impossible d'y mettre ${_natureDe(valeur)}$suffixe.";

      case 'booleen':
        if (valeur is bool) return valeur;
        throw "$cible est un booléen : il ne peut valoir que vrai ou faux, pas ${_natureDe(valeur)}$suffixe.";

      case 'caractere':
        if (valeur is String && valeur.length <= 1) return valeur;
        if (valeur is String) {
          throw "$cible est un caractère : \"$valeur\" en contient ${valeur.length}$suffixe.";
        }
        throw "$cible est un caractère : impossible d'y mettre ${_natureDe(valeur)}$suffixe.";

      case 'chaine':
        if (valeur is String) return valeur;
        throw "$cible est une chaîne : impossible d'y mettre ${_natureDe(valeur)}$suffixe.";

      case 'tableau':
        if (valeur is ArrayData) return valeur;
        throw "$cible est un tableau : impossible d'y mettre ${_natureDe(valeur)}$suffixe.";

      default:
        return valeur;
    }
  }

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
      final nom = argumentNode.name.lexeme;
      environment.assign(
        nom,
        _conformer(value, environment.getType(nom), "'$nom'", argumentNode.name.line),
      );
      onVariableChanged?.call(environment.getAllValues());
    } else if (argumentNode is ArrayAccessNode) {
      final array = environment.get(argumentNode.name.lexeme);
      if (array is ArrayData) {
        final index = _indice(
          await _evaluate(argumentNode.index),
          argumentNode.name.lexeme,
          argumentNode.name.line,
        );
        if (index >= array.lower && index <= array.upper) {
          array.values[index - array.lower] = _conformer(
            value,
            array.baseType,
            "'${argumentNode.name.lexeme}[$index]'",
            argumentNode.name.line,
          );
          onVariableChanged?.call(environment.getAllValues());
        }
      }
    } else {
      throw "Un paramètre 'résultat' ou 'donnée-résultat' doit recevoir une variable (ou un élément de tableau), pas une expression.";
    }
  }

  /// Convertit une saisie clavier vers le type de la variable qui la reçoit.
  ///
  /// Une saisie qui ne correspond pas au type demandé est **refusée**. Rendre
  /// 0 pour « douze » laisserait le programme continuer sur une valeur que
  /// l'utilisateur n'a jamais donnée, et l'erreur ne se manifesterait que bien
  /// plus loin, sous une forme incompréhensible.
  dynamic _cast(String value, String type, [String? cible, int? ligne]) {
    final ou = cible != null ? " pour '$cible'" : "";
    final suffixe = ligne != null ? " (ligne $ligne)" : "";
    switch (_typeCanonique(type)) {
      case 'entier':
        final n = int.tryParse(value.trim());
        if (n != null) return n;
        throw "Saisie invalide$ou : « $value » n'est pas un entier$suffixe.";
      case 'reel':
        final x = double.tryParse(value.trim().replaceAll(',', '.'));
        if (x != null) return x;
        throw "Saisie invalide$ou : « $value » n'est pas un nombre$suffixe.";
      case 'booleen':
        final b = value.trim().toLowerCase();
        if (b == 'vrai' || b == 'true') return true;
        if (b == 'faux' || b == 'false') return false;
        throw "Saisie invalide$ou : « $value » n'est ni vrai ni faux$suffixe.";
      case 'caractere':
        final c = value.trim();
        if (c.length <= 1) return c;
        throw "Saisie invalide$ou : « $value » compte ${c.length} caractères au lieu d'un seul$suffixe.";
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
        final lower = interpreter._borne(await interpreter._evaluate(p.lowerBound!), null);
        final upper = interpreter._borne(await interpreter._evaluate(p.upperBound!), null);
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
      // Un paramètre est une variable comme une autre : son type déclaré
      // engage autant que celui d'une variable locale.
      initialValue = interpreter._conformer(
        initialValue,
        p.isArray ? 'tableau' : p.type,
        "le paramètre '${p.name}'",
        argumentNodes[i].anchor?.line,
      );
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
