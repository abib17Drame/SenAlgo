import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/lexer/lexer.dart';
import '../core/parser/parser.dart';
import '../core/analyzer/semantic_analyzer.dart';
import '../core/interpreter/interpreter.dart';

/// Signal utilisé pour arrêter proprement une exécution en mode pas-à-pas
/// (bouton "Arrêter"), distinct d'une vraie erreur d'exécution.
const String kStoppedByUserSignal = "__SENALGO_STOPPED_BY_USER__";

class ConsoleState {
  final List<String> lines;
  ConsoleState({this.lines = const [""]});
  
  ConsoleState addText(String text) {
    if (text.isEmpty) return this;
    
    List<String> newLines = List.from(lines);
    final textLines = text.split('\n');
    
    // Append first part to the last existing line
    newLines[newLines.length - 1] += textLines[0];
    
    // Add additional lines if there were newlines in the input
    for (int i = 1; i < textLines.length; i++) {
        newLines.add(textLines[i]);
    }
    
    return ConsoleState(lines: newLines);
  }
  
  ConsoleState clear() => ConsoleState(lines: [""]);
}

class ConsoleNotifier extends Notifier<ConsoleState> {
  @override
  ConsoleState build() => ConsoleState();
  void addLine(String text) => state = state.addText(text);
  void clear() => state = state.clear();
}

final consoleProvider = NotifierProvider<ConsoleNotifier, ConsoleState>(ConsoleNotifier.new);

enum ExecutionStatus { idle, running, stepping, waitingForInput, error, finished, stopped }

class ExecutionState {
  final ExecutionStatus status;
  final String? errorMessage;
  final int? currentLine;
  final String? explanation;
  ExecutionState({required this.status, this.errorMessage, this.currentLine, this.explanation});
}

class ExecutionNotifier extends Notifier<ExecutionState> {
  @override
  ExecutionState build() => ExecutionState(status: ExecutionStatus.idle);
  void setStatus(ExecutionStatus status, {String? error, int? line, String? explanation}) => 
    state = ExecutionState(status: status, errorMessage: error, currentLine: line ?? state.currentLine, explanation: explanation ?? state.explanation);
  void setCurrentLine(int? line, {String? explanation}) => state = ExecutionState(status: state.status, errorMessage: state.errorMessage, currentLine: line, explanation: explanation ?? state.explanation);
}

final executionProvider = NotifierProvider<ExecutionNotifier, ExecutionState>(ExecutionNotifier.new);

class VariablesNotifier extends Notifier<Map<String, dynamic>> {
  @override
  Map<String, dynamic> build() => {};
  void setVariables(Map<String, dynamic> vars) => state = vars;
}

final variablesProvider = NotifierProvider<VariablesNotifier, Map<String, dynamic>>(VariablesNotifier.new);

class SourceCodeNotifier extends Notifier<String> {
  @override
  String build() => r"""ALGORITHME MonAlgo
VARIABLES
  a, b, s: entier
DEBUT
  a <- 5
  b <- 10
  s <- a + b
  ecrire("La somme de ", a, " et ", b, " est ", s, "\n")
FIN""";
  void setCode(String code) => state = code;
}

final sourceCodeProvider = NotifierProvider<SourceCodeNotifier, String>(SourceCodeNotifier.new);

class InputCompleterNotifier extends Notifier<Completer<String>?> {
  @override
  Completer<String>? build() => null;
  void setCompleter(Completer<String>? completer) => state = completer;
}

final inputCompleterProvider = NotifierProvider<InputCompleterNotifier, Completer<String>?>(InputCompleterNotifier.new);

class StepCompleterNotifier extends Notifier<Completer<void>?> {
  @override
  Completer<void>? build() => null;
  void setCompleter(Completer<void>? completer) => state = completer;
}

final stepCompleterProvider = NotifierProvider<StepCompleterNotifier, Completer<void>?>(StepCompleterNotifier.new);

class Runner {
  final WidgetRef ref;
  Runner(this.ref);

  Future<void> run(String source, {bool stepByStep = false}) async {
    ref.read(consoleProvider.notifier).clear();
    ref.read(variablesProvider.notifier).setVariables({});
    ref.read(executionProvider.notifier).setStatus(stepByStep ? ExecutionStatus.stepping : ExecutionStatus.running, line: null);
    
    try {
      final tokens = Lexer(source).scanTokens();
      final program = Parser(tokens).parse();

      // Les avertissements de l'analyse sémantique sont affichés puis
      // l'exécution se poursuit : ils signalent une erreur probable, mais
      // c'est à l'utilisateur de juger.
      final avertissements = SemanticAnalyzer().analyser(program);
      for (final a in avertissements) {
        ref.read(consoleProvider.notifier).addLine("⚠ $a\n");
      }
      if (avertissements.isNotEmpty) {
        ref.read(consoleProvider.notifier).addLine("\n");
      }

      final interpreter = Interpreter(
        onPrint: (msg) { ref.read(consoleProvider.notifier).addLine(msg); },
        onRead: () async {
          final completer = Completer<String>();
          ref.read(inputCompleterProvider.notifier).setCompleter(completer);
          ref.read(executionProvider.notifier).setStatus(ExecutionStatus.waitingForInput);
          final result = await completer.future;
          ref.read(executionProvider.notifier).setStatus(stepByStep ? ExecutionStatus.stepping : ExecutionStatus.running);
          ref.read(inputCompleterProvider.notifier).setCompleter(null);
          return result;
        },
        onVariableChanged: (vars) { ref.read(variablesProvider.notifier).setVariables(vars); },
        onStatement: (node, explanation) async {
          if (stepByStep) {
            final line = node.anchor?.line;
            ref.read(executionProvider.notifier).setStatus(ExecutionStatus.stepping, line: line, explanation: explanation);
            final completer = Completer<void>();
            ref.read(stepCompleterProvider.notifier).setCompleter(completer);
            await completer.future;
            ref.read(stepCompleterProvider.notifier).setCompleter(null);
          }
        },
      );
      await interpreter.interpret(program);
      ref.read(executionProvider.notifier).setStatus(ExecutionStatus.finished, line: null);
    } catch (e) {
      if (e.toString().contains(kStoppedByUserSignal)) {
        ref.read(executionProvider.notifier).setStatus(ExecutionStatus.stopped, line: null);
        ref.read(consoleProvider.notifier).addLine("\n⏹ Débogage arrêté par l'utilisateur.");
        ref.read(stepCompleterProvider.notifier).setCompleter(null);
        return;
      }
      ref.read(executionProvider.notifier).setStatus(ExecutionStatus.error, error: e.toString(), line: null);
      ref.read(consoleProvider.notifier).addLine("\n❌ Erreur d'exécution : $e\n");
      ref.read(inputCompleterProvider.notifier).setCompleter(null);
      ref.read(stepCompleterProvider.notifier).setCompleter(null);
    }
  }
}
