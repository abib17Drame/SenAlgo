import '../lexer/token.dart';

/// Statut d'un paramètre de fonction/procédure
/// (sortie, transmis par référence à la fin), donnée-résultat (entrée
/// ET sortie, transmis par référence).
enum ParamMode { donnee, resultat, donneeResultat }

abstract class ASTNode { 
  Token? anchor;
  T accept<T>(ASTVisitor<T> visitor); 
}

abstract class ASTVisitor<T> {
  T visitProgram(ProgramNode node);
  T visitVarDeclaration(VarDeclarationNode node);
  T visitConstDeclaration(ConstDeclarationNode node);
  T visitTypeDeclaration(TypeDeclarationNode node);
  T visitAssignment(AssignmentNode node);
  T visitArrayAssignment(ArrayAssignmentNode node);
  T visitIf(IfNode node);
  T visitWhile(WhileNode node);
  T visitFor(ForNode node);
  T visitRepeat(RepeatNode node);
  T visitFunctionDeclaration(FunctionDeclarationNode node);
  T visitProcedureDeclaration(ProcedureDeclarationNode node);
  T visitCall(CallNode node);
  T visitReturn(ReturnNode node);
  T visitBinary(BinaryNode node);
  T visitUnary(UnaryNode node);
  T visitLiteral(LiteralNode node);
  T visitVariable(VariableNode node);
  T visitArrayAccess(ArrayAccessNode node);
  T visitArrayDeclaration(ArrayDeclarationNode node);
  T visitBlock(BlockNode node);
  T visitExpressionStmt(ExpressionStmtNode node);
  T visitSelon(SelonNode node);
}

class ProgramNode extends ASTNode {
  final String name; final List<ASTNode> declarations; final BlockNode body;
  ProgramNode({required this.name, required this.declarations, required this.body});
  @override T accept<T>(ASTVisitor<T> visitor) => visitor.visitProgram(this);
}

class VarDeclarationNode extends ASTNode {
  final List<String> identifiers; final String type; final ASTNode? initialValue;
  VarDeclarationNode({required this.identifiers, required this.type, this.initialValue});
  @override T accept<T>(ASTVisitor<T> visitor) => visitor.visitVarDeclaration(this);
}

class ConstDeclarationNode extends ASTNode {
  final String identifier; final ASTNode value;
  ConstDeclarationNode({required this.identifier, required this.value});
  @override T accept<T>(ASTVisitor<T> visitor) => visitor.visitConstDeclaration(this);
}

class TypeDeclarationNode extends ASTNode {
  final String identifier; final String typeDefinition;
  TypeDeclarationNode({required this.identifier, required this.typeDefinition});
  @override T accept<T>(ASTVisitor<T> visitor) => visitor.visitTypeDeclaration(this);
}

class AssignmentNode extends ASTNode {
  final String identifier; final ASTNode value;
  AssignmentNode({required this.identifier, required this.value});
  @override T accept<T>(ASTVisitor<T> visitor) => visitor.visitAssignment(this);
}

class ArrayAssignmentNode extends ASTNode {
  final String identifier; final ASTNode index; final ASTNode value;
  ArrayAssignmentNode({required this.identifier, required this.index, required this.value});
  @override T accept<T>(ASTVisitor<T> visitor) => visitor.visitArrayAssignment(this);
}

class IfNode extends ASTNode {
  final ASTNode condition; final BlockNode thenBranch; final List<ElseIfNode> elseIfs; final BlockNode? elseBranch;
  IfNode({required this.condition, required this.thenBranch, this.elseIfs = const [], this.elseBranch});
  @override T accept<T>(ASTVisitor<T> visitor) => visitor.visitIf(this);
}

class ElseIfNode {
  final ASTNode condition; final BlockNode body;
  ElseIfNode({required this.condition, required this.body});
}

class WhileNode extends ASTNode {
  final ASTNode condition; final BlockNode body;
  WhileNode({required this.condition, required this.body});
  @override T accept<T>(ASTVisitor<T> visitor) => visitor.visitWhile(this);
}

class ForNode extends ASTNode {
  final String identifier; final ASTNode startValue; final ASTNode endValue; final ASTNode? step; final BlockNode body;
  ForNode({required this.identifier, required this.startValue, required this.endValue, this.step, required this.body});
  @override T accept<T>(ASTVisitor<T> visitor) => visitor.visitFor(this);
}

class RepeatNode extends ASTNode {
  final BlockNode body; final ASTNode condition;
  RepeatNode({required this.body, required this.condition});
  @override T accept<T>(ASTVisitor<T> visitor) => visitor.visitRepeat(this);
}

class FunctionDeclarationNode extends ASTNode {
  final String name; final List<Parameter> parameters; final String returnType; final BlockNode body;
  /// Déclarations locales (Variables/Constantes) placées entre la liste des
  /// paramètres et Début, comme dans les exemples officiels du cours (ch.5).
  final List<ASTNode> declarations;
  FunctionDeclarationNode({required this.name, required this.parameters, required this.returnType, this.declarations = const [], required this.body});
  @override T accept<T>(ASTVisitor<T> visitor) => visitor.visitFunctionDeclaration(this);
}

class ProcedureDeclarationNode extends ASTNode {
  final String name; final List<Parameter> parameters; final BlockNode body;
  final List<ASTNode> declarations;
  ProcedureDeclarationNode({required this.name, required this.parameters, this.declarations = const [], required this.body});
  @override T accept<T>(ASTVisitor<T> visitor) => visitor.visitProcedureDeclaration(this);
}

class Parameter {
  final String name;
  final String type;
  /// donnée (entrée, par défaut) / résultat (sortie) / donnée-résultat (entrée-sortie).
  final ParamMode mode;
  final bool isArray;
  final ASTNode? lowerBound;
  final ASTNode? upperBound;
  final String? baseType;
  Parameter({
    required this.name,
    required this.type,
    this.mode = ParamMode.donnee,
    this.isArray = false,
    this.lowerBound,
    this.upperBound,
    this.baseType,
  });
}

class CallNode extends ASTNode {
  final String callee; final List<ASTNode> arguments;
  CallNode({required this.callee, required this.arguments});
  @override T accept<T>(ASTVisitor<T> visitor) => visitor.visitCall(this);
}

class ReturnNode extends ASTNode {
  final ASTNode? value;
  ReturnNode({this.value});
  @override T accept<T>(ASTVisitor<T> visitor) => visitor.visitReturn(this);
}

class BinaryNode extends ASTNode {
  final ASTNode left; final Token operator; final ASTNode right;
  BinaryNode({required this.left, required this.operator, required this.right});
  @override T accept<T>(ASTVisitor<T> visitor) => visitor.visitBinary(this);
}

class UnaryNode extends ASTNode {
  final Token operator; final ASTNode right;
  UnaryNode({required this.operator, required this.right});
  @override T accept<T>(ASTVisitor<T> visitor) => visitor.visitUnary(this);
}

class LiteralNode extends ASTNode {
  final dynamic value;
  LiteralNode({required this.value});
  @override T accept<T>(ASTVisitor<T> visitor) => visitor.visitLiteral(this);
}

class VariableNode extends ASTNode {
  final Token name;
  VariableNode({required this.name});
  @override T accept<T>(ASTVisitor<T> visitor) => visitor.visitVariable(this);
}

class ArrayAccessNode extends ASTNode {
  final Token name; final ASTNode index;
  ArrayAccessNode({required this.name, required this.index});
  @override T accept<T>(ASTVisitor<T> visitor) => visitor.visitArrayAccess(this);
}

class ArrayDeclarationNode extends ASTNode {
  final List<String> identifiers;
  final ASTNode lowerBound;
  final ASTNode upperBound;
  final String baseType;
  ArrayDeclarationNode({required this.identifiers, required this.lowerBound, required this.upperBound, required this.baseType});
  @override T accept<T>(ASTVisitor<T> visitor) => visitor.visitArrayDeclaration(this);
}

class BlockNode extends ASTNode {
  final List<ASTNode> statements;
  BlockNode({required this.statements});
  @override T accept<T>(ASTVisitor<T> visitor) => visitor.visitBlock(this);
}

class ExpressionStmtNode extends ASTNode {
  final ASTNode expression;
  ExpressionStmtNode({required this.expression});
  @override T accept<T>(ASTVisitor<T> visitor) => visitor.visitExpressionStmt(this);
}

/// Représente "Selon `<expression>` Faire ... FinSelon"
/// Chaque branche est soit une valeur/expression à comparer
/// par égalité à `<expression>` (ex: "1 : ..."), soit une garde de comparaison
/// (chaînable par et/ou, ex: "< 1000 : ..." ou "≥ 1000 et < 3000 : ...").
/// `guard` est toujours une expression booléenne déjà entièrement construite
/// (elle référence directement le même nœud que `expression`).
class SelonNode extends ASTNode {
  final ASTNode expression;
  final List<SelonCaseNode> cases;
  final BlockNode? defaultBranch;
  SelonNode({required this.expression, required this.cases, this.defaultBranch});
  @override T accept<T>(ASTVisitor<T> visitor) => visitor.visitSelon(this);
}

class SelonCaseNode {
  final ASTNode guard;
  final BlockNode body;
  SelonCaseNode({required this.guard, required this.body});
}
