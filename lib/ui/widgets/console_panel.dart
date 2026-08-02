import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../state/execution_provider.dart';
import '../theme.dart';
import 'panel_shell.dart';

/// Console de sortie du programme, avec la zone de saisie qui apparaît
/// lorsqu'un `Lire` attend une valeur.
///
/// Extrait de `main_screen.dart` lors du découpage. Le contrôleur de la zone
/// de saisie appartient désormais à ce panneau : il n'est utilisé que par lui,
/// et l'écran principal n'a plus à le créer ni à le libérer.
class ConsolePanel extends ConsumerStatefulWidget {
  /// Le panneau des variables est-il visible ? Détermine l'icône du bouton
  /// d'affichage, dont l'état appartient à l'écran principal.
  final bool showVariables;

  /// Bascule l'affichage du panneau des variables. `null` sur petit écran,
  /// où les panneaux sont présentés en onglets.
  final VoidCallback? onToggleVariables;

  const ConsolePanel({super.key, required this.showVariables, this.onToggleVariables});

  @override
  ConsumerState<ConsolePanel> createState() => _ConsolePanelState();
}

class _ConsolePanelState extends ConsumerState<ConsolePanel> {
  final TextEditingController _saisieController = TextEditingController();

  @override
  void dispose() {
    _saisieController.dispose();
    super.dispose();
  }

  void _valider(String valeur) {
    if (valeur.isEmpty) return;
    final completer = ref.read(inputCompleterProvider);
    if (completer == null) return;
    ref.read(consoleProvider.notifier).addLine("> $valeur\n");
    _saisieController.clear();
    completer.complete(valeur);
  }

  void _copierConsole() {
    final consoleState = ref.watch(consoleProvider);
    final ligneCount = consoleState.lines.length;
    final texteACopier = consoleState.lines.join('\n');

    if (texteACopier.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Console vide - rien à copier'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Clipboard.setData(ClipboardData(text: texteACopier)).then((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$ligneCount lignes copiées'),
          duration: Duration(seconds: 2),
          backgroundColor: SenAlgoTheme.neonGreen,
        ),
      );
    }).catchError((error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la copie : $error'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.redAccent,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final consoleState = ref.watch(consoleProvider);
    final executionState = ref.watch(executionProvider);

    return PanelShell(
      title: 'Console',
      icon: Icons.terminal,
      actions: [
        if (widget.onToggleVariables != null)
          IconButton(
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(4),
            icon: Icon(
              widget.showVariables ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 16,
            ),
            onPressed: widget.onToggleVariables,
            tooltip: widget.showVariables ? 'Masquer les variables' : 'Afficher les variables',
          ),
        IconButton(
          constraints: const BoxConstraints(),
          padding: const EdgeInsets.all(4),
          icon: const Icon(Icons.copy, size: 16),
          onPressed: _copierConsole,
          tooltip: 'Copier la console',
        ),
        IconButton(
          constraints: const BoxConstraints(),
          padding: const EdgeInsets.all(4),
          icon: const Icon(Icons.delete_outline, size: 16),
          onPressed: () => ref.read(consoleProvider.notifier).clear(),
          tooltip: 'Effacer la console',
        ),
      ],
      child: Column(
        children: [
          Expanded(
            child: SelectionArea(
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: consoleState.lines.length,
                itemBuilder: (context, index) => Text(
                  consoleState.lines[index],
                  style: GoogleFonts.firaCode(color: Colors.white, fontSize: 13),
                ),
              ),
            ),
          ),
          if (executionState.status == ExecutionStatus.waitingForInput) _buildSaisie(),
        ],
      ),
    );
  }

  Widget _buildSaisie() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(
        color: Colors.black26,
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          const Text("> ", style: TextStyle(color: SenAlgoTheme.neonGreen)),
          Expanded(
            child: TextField(
              controller: _saisieController,
              autofocus: true,
              style: GoogleFonts.firaCode(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: "Saisir une valeur...",
                hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              onSubmitted: _valider,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send_rounded, color: SenAlgoTheme.neonCyan, size: 18),
            onPressed: () => _valider(_saisieController.text),
            tooltip: 'Valider',
          ),
        ],
      ),
    );
  }
}
