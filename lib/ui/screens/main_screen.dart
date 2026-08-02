import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import '../../state/execution_provider.dart';
import '../../state/diagnostics_provider.dart';
import '../theme.dart';
import '../editor_highlight.dart';
import 'package:highlight/highlight.dart' show Mode;
import '../examples/example_programs.dart';
import '../editor/senalgo_enter_modifier.dart';
import '../widgets/resizable_split_view.dart';
import '../widgets/execution_status_view.dart';
import '../widgets/diagnostics_badge.dart';
import '../widgets/editor_panel.dart';
import '../widgets/console_panel.dart';
import '../widgets/variables_panel.dart';
import '../widgets/app_toolbar.dart';
import '../dialogs/python_translation_dialog.dart';
import '../services/algo_file_service.dart';
import '../services/auto_save_service.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  late CodeController _codeController;
  bool _showVariables = true;
  bool _autoPlayEnabled = false;

  /// Retour à la ligne automatique dans l'éditeur. Activé par défaut : sans
  /// lui, une instruction un peu longue sort de l'écran sur un téléphone.
  bool _wrapLines = true;
  int _selectedTabIndex = 0; // 0: Editor, 1: Console, 2: Variables
  
  Timer? _diagnosticsTimer;

  /// Toutes les casses des mots-clés du langage (calculé une seule fois),
  /// base de la liste d'autocomplétion à laquelle s'ajoutent les symboles
  /// déclarés par l'utilisateur.
  final Set<String> _keywordVariations = {};

  final List<String> _keywords = [
    'ALGORITHME', 'VARIABLES', 'VAR', 'CONSTANTES', 'DEBUT', 'FIN', 'SI', 'ALORS', 'SINON', 'SINONSI',
    'FINSI', 'TANT QUE', 'FINTANT QUE', 'FAIRE', 'POUR', 'FINPOUR', 'ALLANT', 'DE', 'A',
    'REPETER', 'JUSQU\'À', 'SELON', 'FINSELON',
    'FONCTION', 'PROCEDURE', 'RETOURNER', 'DONNÉE', 'RÉSULTAT', 'DONNÉE-RÉSULTAT',
    'VRAI', 'FAUX', 'ET', 'OU', 'NON',
    'afficher', 'saisir', 'ecrire', 'ecrireln', 'lire', 'entier', 'réel', 'booléen', 'chaîne', 'abs', 'racine'
  ];

  /// Programme affiché au démarrage, avant toute reprise ou saisie. Sert de
  /// témoin pour savoir si l'utilisateur a déjà touché à l'éditeur.
  late final String _programmeInitial;

  @override
  void initState() {
    super.initState();
    _programmeInitial = ref.read(sourceCodeProvider);
    _codeController = CodeController(
      text: _programmeInitial,
      language: Mode(
        case_insensitive: true,
        refs: {},
        keywords: SenAlgoMode.senalgo['keywords'],
        contains: [
          Mode(className: 'string', begin: '"', end: '"'),
          Mode(className: 'string', begin: "'", end: "'"),
          Mode(className: 'comment', begin: '//', end: '\$'),
          Mode(className: 'comment', begin: '{', end: '}'),
          Mode(className: 'number', begin: '\\b\\d+(\\.\\d+)?\\b'),
          Mode(className: 'operator', begin: '<-|:=|=|<|>|≠|\\+|-|\\*|\\^|/|\\.\\.'),
        ],
      ),
      modifiers: [
        const SenAlgoEnterModifier(),
        ...CodeController.defaultCodeModifiers.where((m) => m.char != '\n'),
      ],
    );

    // FIX FLUTTER_CODE_EDITOR BUGS (Cursor placement on Enter & Ghost Popups on Tab)
    try {
      final enterIntentType = _codeController.actions.keys.firstWhere((k) => k.toString() == 'EnterKeyIntent');
      _codeController.actions[enterIntentType] = CallbackAction<Intent>(
        onInvoke: (intent) {
          if (_codeController.popupController.shouldShow) {
            _codeController.insertSelectedWord();
            return null;
          }
          final sel = _codeController.selection;
          final text = _codeController.text;
          if (!sel.isValid) return null;
          
          final newValue = TextEditingValue(
            text: text.replaceRange(sel.start, sel.end, '\n'),
            selection: TextSelection.collapsed(offset: sel.start + 1),
          );
          _codeController.value = newValue;
          return null;
        },
      );

      final tabIntentType = _codeController.actions.keys.firstWhere((k) => k.toString() == 'TabKeyIntent');
      _codeController.actions[tabIntentType] = CallbackAction<Intent>(
        onInvoke: (intent) {
          final word = _codeController.value.wordAtCursor;
          if (_codeController.popupController.shouldShow && word != null && word.isNotEmpty) {
            _codeController.insertSelectedWord();
            return null;
          }
          _codeController.insertStr('  ');
          return null;
        },
      );
    } catch (e) {
      debugPrint("Action override failed: $e");
    }
    
    for (final kw in _keywords) {
      final w = kw.trim();
      if (w.isEmpty) continue;
      _keywordVariations.add(w.toLowerCase());
      _keywordVariations.add(w.toUpperCase());
      _keywordVariations.add(w.substring(0, 1).toUpperCase() + w.substring(1).toLowerCase());
    }
    _refreshAutocompleteWords();

    _codeController.addListener(() {
      ref.read(sourceCodeProvider.notifier).setCode(_codeController.text);
      _scheduleDiagnostics();
    });
    _scheduleDiagnostics();
    _reprendreProgramme();
  }

  /// Recharge le programme de la session précédente, s'il y en a un.
  ///
  /// La lecture du stockage est asynchrone : l'utilisateur peut donc avoir
  /// commencé à taper entre-temps. Dans ce cas son texte prime, on n'écrase
  /// rien, d'où la comparaison avec le programme affiché au démarrage.
  Future<void> _reprendreProgramme() async {
    final source = await AutoSaveService.reprendre();
    if (source == null || !mounted) return;
    if (_codeController.text != _programmeInitial) return;
    _codeController.text = source;
  }

  /// Analyse (approximative, par expressions régulières) le texte du
  /// programme pour en extraire les noms de variables, constantes, fonctions
  /// et procédures déclarés par l'utilisateur, afin que l'autocomplétion les
  /// propose au même titre que les mots-clés du langage.
  Set<String> _extractUserSymbols(String source) {
    final symbols = <String>{};
    for (final m in RegExp(r'(?:fonction|procedure|procédure)\s+([a-zA-Zà-ÿÀ-ß_][a-zA-Zà-ÿÀ-ß0-9_]*)', caseSensitive: false).allMatches(source)) {
      symbols.add(m.group(1)!);
    }
    for (final line in source.split('\n')) {
      final declMatch = RegExp(r'^\s*([a-zA-Zà-ÿÀ-ß_][a-zA-Zà-ÿÀ-ß0-9_,\s]*)\s*:\s*[a-zA-Zà-ÿÀ-ß]').firstMatch(line);
      if (declMatch == null) continue;
      for (final n in declMatch.group(1)!.split(',')) {
        final name = n.trim();
        if (name.isEmpty) continue;
        if (_keywords.any((k) => k.toLowerCase() == name.toLowerCase())) continue;
        symbols.add(name);
      }
    }
    return symbols;
  }

  /// Reconstruit la liste de complétion : mots-clés du langage + noms
  /// déclarés par l'utilisateur dans le programme en cours d'édition.
  void _refreshAutocompleteWords() {
    _codeController.autocompleter.setCustomWords(
      {..._keywordVariations, ..._extractUserSymbols(_codeController.text)}.toList(),
    );
  }

  @override
  void dispose() {
    _autoPlayEnabled = false;
    _diagnosticsTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _toggleAutoPlay() {
    setState(() => _autoPlayEnabled = !_autoPlayEnabled);
    if (_autoPlayEnabled) {
      _runAutoPlayCycle();
    }
  }

  void _runAutoPlayCycle() async {
    if (!mounted || !_autoPlayEnabled) return;
    
    final state = ref.read(executionProvider);
    if (state.status == ExecutionStatus.stepping) {
      final completer = ref.read(stepCompleterProvider);
      if (completer != null && !completer.isCompleted) {
        completer.complete();
      }
    } else if (state.status == ExecutionStatus.idle || state.status == ExecutionStatus.error || state.status == ExecutionStatus.finished || state.status == ExecutionStatus.stopped) {
      if (mounted) setState(() => _autoPlayEnabled = false);
      return;
    }
    
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted && _autoPlayEnabled) {
      _runAutoPlayCycle();
    }
  }

  /// Lance une analyse lexicale + syntaxique en tâche de fond (avec un léger
  /// délai pour ne pas analyser à chaque frappe), pour signaler les erreurs
  /// AVANT même que l'utilisateur ne clique sur Exécuter.
  void _scheduleDiagnostics() {
    _diagnosticsTimer?.cancel();
    _diagnosticsTimer = Timer(const Duration(milliseconds: 400), _runDiagnostics);
  }

  void _runDiagnostics() {
    if (!mounted) return;
    // Profite du même déclenchement différé que l'analyse pour ne pas
    // ré-extraire les symboles à chaque frappe.
    _refreshAutocompleteWords();
    ref.read(diagnosticsProvider.notifier).analyser(_codeController.text);
    // La barre du bas rend compte d'un programme qui vient de tourner. Le
    // texte a changé depuis : son verdict porte sur des lignes qui n'existent
    // plus sous cette forme, et le numéro qu'il cite désigne autre chose.
    // On revient donc à l'état neutre, jusqu'au prochain lancement.
    final statut = ref.read(executionProvider).status;
    if (statut == ExecutionStatus.error ||
        statut == ExecutionStatus.finished ||
        statut == ExecutionStatus.stopped) {
      ref.read(executionProvider.notifier).setStatus(ExecutionStatus.idle, line: null);
    }
    // Même logique pour la sauvegarde automatique : écrire à chaque touche
    // serait inutile, 400 ms après la dernière frappe suffit largement.
    AutoSaveService.enregistrer(_codeController.text);
  }

  /// Place le curseur au début de la ligne signalée par les diagnostics,
  /// pour permettre de sauter directement à l'erreur.
  void _jumpToDiagnosticLine() {
    final ligne = ref.read(diagnosticsProvider).ligneAAtteindre;
    if (ligne == null) return;
    final lines = _codeController.text.split('\n');
    final targetLine = (ligne - 1).clamp(0, lines.length - 1);
    int offset = 0;
    for (int i = 0; i < targetLine; i++) {
      offset += lines[i].length + 1;
    }
    _codeController.selection = TextSelection.collapsed(offset: offset);
  }

  /// Badge d'état, cf. [DiagnosticsBadge].
  Widget _buildDiagnosticsBadge() {
    final diagnostics = ref.watch(diagnosticsProvider);
    return DiagnosticsBadge(
      error: diagnostics.error,
      errorLine: diagnostics.errorLine,
      warnings: diagnostics.warnings,
      onTap: _jumpToDiagnosticLine,
    );
  }

  @override
  Widget build(BuildContext context) {
    final executionState = ref.watch(executionProvider);

    ref.listen<ExecutionState>(executionProvider, (previous, next) {
      if (next.status == ExecutionStatus.error) {
        if (mounted) setState(() => _autoPlayEnabled = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(next.errorMessage ?? "Erreur inconnue")),
              ],
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (next.status == ExecutionStatus.finished || next.status == ExecutionStatus.stopped) {
        if (mounted) setState(() => _autoPlayEnabled = false);
      }
    });

    final consoleState = ref.watch(consoleProvider);
    final variables = ref.watch(variablesProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 800;
        // En dessous de ce seuil, même la barre d'outils « mobile » ne tient
        // plus en largeur : les boutons d'action passent en icône seule.
        final isCompact = constraints.maxWidth < 420;

        return Scaffold(
          appBar: AppToolbar(
            isMobile: isMobile,
            isCompact: isCompact,
            executionState: executionState,
            autoPlayEnabled: _autoPlayEnabled,
            examplesMenu: _buildExamplesMenu(),
            onOpenFile: _openFile,
            onSaveFile: _saveFile,
            onNewFile: _createNewFile,
            onClearCode: () => _codeController.clear(),
            onShowPython: _showPythonTranslation,
            onStop: () {
              setState(() => _autoPlayEnabled = false);
              // Débloque le pas-à-pas ou l'attente de saisie...
              ref.read(stepCompleterProvider)?.completeError(kStoppedByUserSignal);
              ref.read(inputCompleterProvider)?.completeError(kStoppedByUserSignal);
              // ...et prévient l'interpréteur, seul moyen d'arrêter une
              // exécution normale, qui ne s'interrompt sur rien.
              ref.read(runningInterpreterProvider)?.demanderArret();
            },
            onStep: () {
              setState(() => _autoPlayEnabled = false);
              ref.read(stepCompleterProvider)?.complete();
            },
            onToggleAutoPlay: _toggleAutoPlay,
            onRunStepByStep: () {
              Runner(ref).run(_codeController.text, stepByStep: true);
              if (isMobile) setState(() => _selectedTabIndex = 1);
            },
            onRun: () {
              Runner(ref).run(_codeController.text);
              if (isMobile) setState(() => _selectedTabIndex = 1);
            },
          ),
          body: isMobile 
            ? IndexedStack(
                index: _selectedTabIndex,
                children: [
                  _buildEditorPanel(executionState),
                  _buildConsolePanel(consoleState, executionState),
                  _buildVariablesPanel(variables),
                ],
              )
            : ResizableSplitView(
                axis: Axis.horizontal,
                initialRatio: 0.6,
                child1: _buildEditorPanel(executionState),
                child2: _showVariables 
                  ? ResizableSplitView(
                      axis: Axis.vertical,
                      initialRatio: 0.65,
                      child1: _buildConsolePanel(consoleState, executionState),
                      child2: _buildVariablesPanel(variables),
                    )
                  : _buildConsolePanel(consoleState, executionState),
              ),
          bottomNavigationBar: isMobile 
            ? BottomNavigationBar(
                currentIndex: _selectedTabIndex,
                onTap: (index) => setState(() => _selectedTabIndex = index),
                backgroundColor: Colors.black,
                selectedItemColor: SenAlgoTheme.neonCyan,
                unselectedItemColor: Colors.grey,
                elevation: 10,
                type: BottomNavigationBarType.fixed,
                items: const [
                  BottomNavigationBarItem(icon: Icon(Icons.code), label: 'Code'),
                  BottomNavigationBarItem(icon: Icon(Icons.terminal), label: 'Console'),
                  BottomNavigationBarItem(icon: Icon(Icons.memory), label: 'Variables'),
                ],
              )
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: const BoxDecoration(
                  color: Colors.black,
                  border: Border(top: BorderSide(color: Colors.white10)),
                ),
                child: Row(
                  children: [
                    _buildStatusIndicator(executionState.status),
                    const SizedBox(width: 8),
                    Text(
                      _getStatusMessage(executionState),
                      style: TextStyle(
                        color: _getStatusColor(executionState.status),
                        fontSize: 11,
                      ),
                    ),
                    const Spacer(),
                    Flexible(child: _buildDiagnosticsBadge()),
                  ],
                ),
              ),
        );
      }
    );
  }

  Widget _buildEditorPanel(ExecutionState executionState) {
    return EditorPanel(
      controller: _codeController,
      diagnosticsBadge: _buildDiagnosticsBadge(),
      debugLine: executionState.status == ExecutionStatus.stepping
          ? executionState.currentLine
          : null,
      wrapLines: _wrapLines,
      onToggleWrap: () => setState(() => _wrapLines = !_wrapLines),
      onRun: () {
        if (executionState.status == ExecutionStatus.running) return;
        Runner(ref).run(_codeController.text);
        if (MediaQuery.of(context).size.width < 800) {
          setState(() => _selectedTabIndex = 1);
        }
      },
      onSave: _saveFile,
    );
  }

  Widget _buildConsolePanel(ConsoleState consoleState, ExecutionState executionState) {
    final estLarge = MediaQuery.of(context).size.width >= 800;
    return ConsolePanel(
      showVariables: _showVariables,
      onToggleVariables:
          estLarge ? () => setState(() => _showVariables = !_showVariables) : null,
    );
  }

  Widget _buildVariablesPanel(Map<String, dynamic> variables) =>
      VariablesPanel(variables: variables);

  Widget _buildStatusIndicator(ExecutionStatus status) => ExecutionStatusDot(status: status);

  String _getStatusMessage(ExecutionState state) => ExecutionStatusDot.messagePour(state);

  Color _getStatusColor(ExecutionStatus status) => ExecutionStatusDot.couleurPour(status);


  Future<void> _openFile() async {
    // Le ScaffoldMessenger est récupéré AVANT le premier await : le sélecteur
    // de fichier est asynchrone, et l'écran pourrait avoir été démonté entre
    // temps (utiliser `context` après coup lèverait une exception).
    final messenger = ScaffoldMessenger.of(context);
    try {
      final contents = await AlgoFileService.pickAndRead();
      if (contents == null || !mounted) return;
      _codeController.fullText = contents;
      messenger.showSnackBar(
        const SnackBar(content: Text('Fichier chargé avec succès'), backgroundColor: SenAlgoTheme.neonGreen),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Erreur lors du chargement: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _saveFile() async {
    // Voir _openFile : messager capturé avant tout await.
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (!await AlgoFileService.pickAndWrite(_codeController.text)) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Fichier sauvegardé avec succès'), backgroundColor: SenAlgoTheme.neonGreen),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Erreur lors de la sauvegarde: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  void _createNewFile() {
    _codeController.text = """ALGORITHME NomDeLAlgorithme
CONSTANTES
  // Définissez vos constantes ici (ex: PI = 3.14)

VARIABLES
  // Déclarez vos variables ici (ex: x: entier)

DEBUT
  // Écrivez vos instructions ici
  ecrire("Bonjour SenAlgo !\\n")
FIN""";
  }


  void _showPythonTranslation() {
    showPythonTranslationDialog(context, _codeController.text);
  }

  Widget _buildExamplesMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.lightbulb_outline, color: SenAlgoTheme.neonYellow),
      tooltip: 'Exemples',
      onSelected: (code) {
        _codeController.fullText = code;
      },
      itemBuilder: (context) => [
        for (final exemple in kExamplePrograms) ...[
          if (exemple.startsGroup) const PopupMenuDivider(),
          PopupMenuItem(value: exemple.code, child: Text(exemple.title)),
        ],
      ],
    );
  }

}



