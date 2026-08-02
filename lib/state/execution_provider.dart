import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/lexer/lexer.dart';
import '../core/parser/parser.dart';
import '../core/analyzer/semantic_analyzer.dart';
import '../core/interpreter/interpreter.dart';

// Le signal d'arrêt est défini par l'interpréteur, qui est seul à le lever.
// Il est ré-exporté ici pour que l'interface n'ait pas à importer le cœur.
export '../core/interpreter/interpreter.dart' show kStoppedByUserSignal;

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

/// L'interpréteur de l'exécution en cours, `null` s'il n'y en a pas.
///
/// Exposé pour que le bouton « Arrêter » puisse l'interrompre. En pas-à-pas et
/// en attente de saisie il suffisait de débloquer le `Completer` correspondant ;
/// une exécution normale, elle, ne s'arrête sur rien, et c'est l'interpréteur
/// lui-même qu'il faut prévenir.
class RunningInterpreterNotifier extends Notifier<Interpreter?> {
  @override
  Interpreter? build() => null;
  void setInterpreter(Interpreter? interpreter) => state = interpreter;
}

final runningInterpreterProvider = NotifierProvider<RunningInterpreterNotifier, Interpreter?>(RunningInterpreterNotifier.new);

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

      // L'analyse sémantique décide si le programme a le droit de démarrer.
      // Une erreur est un fait établi : affecter une chaîne à un entier,
      // tester une condition qui n'en est pas une. Le faire tourner quand même
      // ne produirait qu'un résultat faux, plus difficile à comprendre que le
      // refus. Un avertissement, lui, s'affiche et laisse passer.
      final signalements = SemanticAnalyzer().analyser(program);
      final erreurs = signalements.where((d) => d.estErreur).toList();

      for (final d in signalements) {
        ref.read(consoleProvider.notifier).addLine("${d.estErreur ? "❌" : "⚠"} $d\n");
      }

      if (erreurs.isNotEmpty) {
        final n = erreurs.length;
        ref.read(consoleProvider.notifier).addLine(
              "\n⛔ Exécution refusée : $n erreur${n > 1 ? "s" : ""} à corriger.\n",
            );
        ref.read(executionProvider.notifier).setStatus(
              ExecutionStatus.error,
              error: erreurs.first.message,
              line: erreurs.first.line,
            );
        return;
      }

      if (signalements.isNotEmpty) {
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
      ref.read(runningInterpreterProvider.notifier).setInterpreter(interpreter);
      await interpreter.interpret(program);
      ref.read(executionProvider.notifier).setStatus(ExecutionStatus.finished, line: null);
    } catch (e) {
      if (e.toString().contains(kStoppedByUserSignal)) {
        ref.read(executionProvider.notifier).setStatus(ExecutionStatus.stopped, line: null);
        ref.read(consoleProvider.notifier).addLine("\n⏹ Exécution arrêtée par l'utilisateur.");
        ref.read(stepCompleterProvider.notifier).setCompleter(null);
        return;
      }
      ref.read(executionProvider.notifier).setStatus(ExecutionStatus.error, error: e.toString(), line: null);
      ref.read(consoleProvider.notifier).addLine("\n❌ Erreur d'exécution : $e\n");
      ref.read(inputCompleterProvider.notifier).setCompleter(null);
      ref.read(stepCompleterProvider.notifier).setCompleter(null);
    } finally {
      // Sans ça, le bouton « Arrêter » d'une exécution suivante interromprait
      // un interpréteur déjà terminé.
      ref.read(runningInterpreterProvider.notifier).setInterpreter(null);
    }
  }
}
