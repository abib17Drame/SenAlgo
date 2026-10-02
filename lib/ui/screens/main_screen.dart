import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import '../../state/execution_provider.dart';
import '../../state/diagnostics_provider.dart';
import '../theme.dart';
import '../editor_highlight.dart';
import '../editor/senalgo_enter_modifier.dart';
import '../widgets/resizable_split_view.dart';
import '../widgets/execution_status_view.dart';
import '../widgets/diagnostics_badge.dart';
import '../widgets/editor_panel.dart';
import '../widgets/console_panel.dart';
import '../widgets/variables_panel.dart';
import '../widgets/app_toolbar.dart';
import '../dialogs/python_translation_dialog.dart';
import '../dialogs/examples_dialog.dart';
import '../dialogs/language_guide.dart';
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
      language: SenAlgoMode.grammaire,
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
          if (_completionApplicable()) {
            _codeController.insertSelectedWord();
            return null;
          }
          final sel = _codeController.selection;
          final text = _codeController.text;
          if (!sel.isValid) return null;
          
          // Le raccourci doit produire l'indentation et son curseur ensemble,
          // sans dépendre de la détection d'insertion du package sur le Web.
          final newValue = const SenAlgoEnterModifier().updateString(
            text, sel, _codeController.params,
          );
          if (newValue != null) _codeController.value = newValue;
          return null;
        },
      );

      final tabIntentType = _codeController.actions.keys.firstWhere((k) => k.toString() == 'TabKeyIntent');
      _codeController.actions[tabIntentType] = CallbackAction<Intent>(
        onInvoke: (intent) {
          if (_completionApplicable()) {
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

  /// Une complétion peut-elle s'appliquer sans risque ?
  ///
  /// `insertSelectedWord` remplace tout le mot sous le curseur par la
  /// suggestion retenue. Or le popup garde ses suggestions après avoir été
  /// masqué, et `shouldShow` est un drapeau séparé : validé au mauvais moment,
  /// il écrasait un mot du programme par un autre sans rapport. On exige donc
  /// que la suggestion prolonge vraiment ce qui vient d'être tapé.
  bool _completionApplicable() {
    if (!_codeController.popupController.shouldShow) return false;
    final mot = _codeController.value.wordAtCursor;
    if (mot == null || mot.isEmpty) return false;
    final String suggestion;
    try {
      suggestion = _codeController.popupController.getSelectedWord();
    } catch (_) {
      // Liste jamais remplie ou index hors bornes : rien à insérer.
      return false;
    }
    return suggestion.isNotEmpty &&
        suggestion.toLowerCase().startsWith(mot.toLowerCase());
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
    // `fullText` et non `text` : le second traite l'affectation comme une
    // frappe et diffe l'ancien texte avec le nouveau, ce qui rendait un
    // fragment au lieu du programme.
    _codeController.fullText = source;
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
      onTap: _showDiagnostics,
    );
  }

  void _showDiagnostics() {
    final diagnostics = ref.read(diagnosticsProvider);
    _jumpToDiagnosticLine();
    FocusManager.instance.primaryFocus?.unfocus();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (sheetContext) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.75),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              const Expanded(child: Text('Diagnostics du programme', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
              IconButton(tooltip: 'Fermer les diagnostics', onPressed: () => Navigator.pop(sheetContext), icon: const Icon(Icons.close_rounded)),
            ]),
            const SizedBox(height: 8),
            const Text('Le curseur est placé sur la première ligne signalée.', style: TextStyle(color: SenAlgoTheme.muted, fontSize: 13, height: 1.5)),
            const SizedBox(height: 16),
            if (diagnostics.error != null)
              _diagnosticCard(diagnostics.error!, true)
            else
              for (final diagnostic in diagnostics.warnings)
                _diagnosticCard(diagnostic.toString(), diagnostic.estErreur),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: ElevatedButton.icon(
              onPressed: () { Navigator.pop(sheetContext); setState(() => _selectedTabIndex = 0); },
              icon: const Icon(Icons.edit_outlined, size: 18), label: const Text('Revenir au code'),
            )),
          ]),
        ),
      ),
    );
  }

  Widget _diagnosticCard(String message, bool error) {
    final color = error ? const Color(0xFFFF9B9B) : SenAlgoTheme.neonYellow;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(error ? Icons.error_outline_rounded : Icons.warning_amber_rounded, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(child: SelectableText(message, style: const TextStyle(fontSize: 13, height: 1.6))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final executionState = ref.watch(executionProvider);

    ref.listen<ExecutionState>(executionProvider, (previous, next) {
      const terminees = {
        ExecutionStatus.error,
        ExecutionStatus.finished,
        ExecutionStatus.stopped,
      };
      if (next.status == ExecutionStatus.waitingForInput &&
          MediaQuery.sizeOf(context).width < 800 && mounted) {
        setState(() => _selectedTabIndex = 1);
      }
      if (terminees.contains(next.status) && mounted) {
        setState(() => _autoPlayEnabled = false);
      }
    });

    final consoleState = ref.watch(consoleProvider);
    final variables = ref.watch(variablesProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 800;
        // Le sous-titre de marque laisse la place aux outils sur petit écran.
        final isCompact = constraints.maxWidth < 420;
        final isTablet = constraints.maxWidth >= 600 && isMobile;
        final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;

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
            onShowHelp: () => showLanguageGuide(context),
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
              FocusManager.instance.primaryFocus?.unfocus();
              Runner(ref).run(_codeController.text, stepByStep: true);
              if (isMobile) setState(() => _selectedTabIndex = 0);
            },
            onRun: () {
              FocusManager.instance.primaryFocus?.unfocus();
              Runner(ref).run(_codeController.text);
              if (isMobile) setState(() => _selectedTabIndex = 1);
            },
          ),
          body: SafeArea(
            top: false,
            bottom: false,
            child: Column(
              children: [
                if (isMobile && (executionState.status != ExecutionStatus.idle))
                  _buildExecutionStrip(executionState),
                Expanded(child: isMobile
                  ? Row(children: [
                      if (isTablet && !keyboardVisible)
                        NavigationRail(
                          selectedIndex: _selectedTabIndex,
                          backgroundColor: SenAlgoTheme.darkBg,
                          indicatorColor: SenAlgoTheme.neonGreen.withValues(alpha: 0.14),
                          labelType: NavigationRailLabelType.all,
                          onDestinationSelected: (index) {
                            FocusManager.instance.primaryFocus?.unfocus();
                            setState(() => _selectedTabIndex = index);
                          },
                          destinations: const [
                            NavigationRailDestination(icon: Icon(Icons.code_rounded), label: Text('Code')),
                            NavigationRailDestination(icon: Icon(Icons.terminal_rounded), label: Text('Console')),
                            NavigationRailDestination(icon: Icon(Icons.data_object_rounded), label: Text('Variables')),
                          ],
                        ),
                      Expanded(child: IndexedStack(
                        index: _selectedTabIndex,
                        children: [
                          _buildEditorPanel(executionState),
                          _buildConsolePanel(consoleState, executionState),
                          _buildVariablesPanel(variables),
                        ],
                      )),
                    ])
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: ResizableSplitView(
                        axis: Axis.horizontal,
                        initialRatio: 0.6,
                        child1: _buildEditorPanel(executionState),
                        child2: _showVariables
                          ? ResizableSplitView(
                              axis: Axis.vertical, initialRatio: 0.65,
                              child1: _buildConsolePanel(consoleState, executionState),
                              child2: _buildVariablesPanel(variables),
                            )
                          : _buildConsolePanel(consoleState, executionState),
                      ),
                    )),
              ],
            ),
          ),
          bottomNavigationBar: isMobile
            ? (keyboardVisible || isTablet ? null : NavigationBar(
                selectedIndex: _selectedTabIndex,
                onDestinationSelected: (index) {
                  FocusManager.instance.primaryFocus?.unfocus();
                  setState(() => _selectedTabIndex = index);
                },
                destinations: [
                  const NavigationDestination(icon: Icon(Icons.code_rounded), label: 'Code'),
                  NavigationDestination(
                    icon: Badge(isLabelVisible: executionState.status == ExecutionStatus.waitingForInput,
                      smallSize: 8, child: const Icon(Icons.terminal_rounded)),
                    label: 'Console',
                  ),
                  NavigationDestination(icon: Badge(isLabelVisible: variables.isNotEmpty,
                    label: Text('${variables.length}'), child: const Icon(Icons.data_object_rounded)), label: 'Variables'),
                ],
              ))
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: const BoxDecoration(color: SenAlgoTheme.darkBg, border: Border(top: BorderSide(color: SenAlgoTheme.border))),
                child: Row(children: [
                  _buildStatusIndicator(executionState.status),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_getStatusMessage(executionState), overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _getStatusColor(executionState.status), fontSize: 12))),
                  const SizedBox(width: 16),
                  const Icon(Icons.restore_rounded, color: SenAlgoTheme.muted, size: 16),
                  const SizedBox(width: 8),
                  const Text('Reprise automatique', style: TextStyle(color: SenAlgoTheme.muted, fontSize: 11)),
                ]),
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
      setState(() => _selectedTabIndex = 0);
      messenger.showSnackBar(
        const SnackBar(content: Text('Fichier chargé avec succès', style: TextStyle(color: SenAlgoTheme.darkBg)), backgroundColor: SenAlgoTheme.neonGreen),
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
        const SnackBar(content: Text('Fichier sauvegardé avec succès', style: TextStyle(color: SenAlgoTheme.darkBg)), backgroundColor: SenAlgoTheme.neonGreen),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Erreur lors de la sauvegarde: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  void _createNewFile() {
    setState(() => _selectedTabIndex = 0);
    _codeController.fullText = """ALGORITHME NomDeLAlgorithme
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
    FocusManager.instance.primaryFocus?.unfocus();
    showPythonTranslationDialog(context, _codeController.text);
  }

  Widget _buildExamplesMenu() {
    return IconButton(
      icon: const Icon(Icons.auto_stories_outlined, color: SenAlgoTheme.neonCyan, size: 21),
      tooltip: 'Exemples',
      onPressed: () async {
        FocusManager.instance.primaryFocus?.unfocus();
        final code = await showExamplesLibrary(context);
        if (code == null || !mounted) return;
        _codeController.fullText = code;
        setState(() => _selectedTabIndex = 0);
      },
    );
  }

  Widget _buildExecutionStrip(ExecutionState state) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: SenAlgoTheme.raisedSurface, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        ExecutionStatusDot(status: state.status),
        const SizedBox(width: 10),
        Expanded(child: Text(ExecutionStatusDot.messagePour(state), maxLines: 2,
          overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, height: 1.5))),
        if (state.status == ExecutionStatus.stepping && _selectedTabIndex == 0)
          TextButton(onPressed: () => setState(() => _selectedTabIndex = 2),
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
            child: const Text('Variables', style: TextStyle(fontSize: 12))),
      ]),
    );
  }
}
