import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../state/execution_provider.dart';
import '../theme.dart';

/// Barre d'outils de l'application : titre, actions sur le fichier, menu des
/// exemples, traduction Python et commandes d'exécution.
///
/// Extraite de `main_screen.dart` lors du découpage. Toutes les actions sont
/// reçues sous forme de rappels : ce widget ne connaît ni l'éditeur, ni
/// l'interpréteur.
class AppToolbar extends StatelessWidget implements PreferredSizeWidget {
  /// Largeur inférieure à 800 : les panneaux passent en onglets et les
  /// actions sur le fichier disparaissent de la barre.
  final bool isMobile;

  /// Largeur inférieure à 420 : les boutons perdent leur libellé, faute de
  /// place, et n'affichent plus que leur icône.
  final bool isCompact;

  final ExecutionState executionState;
  final bool autoPlayEnabled;

  /// Menu des exemples, construit par l'écran principal qui détient
  /// l'éditeur dans lequel le programme choisi est chargé.
  final Widget examplesMenu;

  final VoidCallback onOpenFile;
  final VoidCallback onSaveFile;
  final VoidCallback onNewFile;
  final VoidCallback onClearCode;
  final VoidCallback onShowPython;

  /// Arrête une exécution pas à pas en cours.
  final VoidCallback onStop;

  /// Passe à l'instruction suivante en mode pas à pas.
  final VoidCallback onStep;

  final VoidCallback onToggleAutoPlay;
  final VoidCallback onRunStepByStep;
  final VoidCallback onRun;

  const AppToolbar({
    super.key,
    required this.isMobile,
    required this.isCompact,
    required this.executionState,
    required this.autoPlayEnabled,
    required this.examplesMenu,
    required this.onOpenFile,
    required this.onSaveFile,
    required this.onNewFile,
    required this.onClearCode,
    required this.onShowPython,
    required this.onStop,
    required this.onStep,
    required this.onToggleAutoPlay,
    required this.onRunStepByStep,
    required this.onRun,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
      return AppBar(
        titleSpacing: isCompact ? 8 : null,
        title: Text(
          'SenAlgo',
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.audiowide(color: SenAlgoTheme.neonCyan, fontSize: isCompact ? 16 : (isMobile ? 18 : 22)),
        ),
        actions: [
          if (!isMobile) ...[
            IconButton(
              icon: const Icon(Icons.folder_open_outlined, color: SenAlgoTheme.neonCyan),
              onPressed: onOpenFile,
              tooltip: 'Ouvrir un fichier .algo',
            ),
            IconButton(
              icon: const Icon(Icons.save_outlined, color: SenAlgoTheme.neonGreen),
              onPressed: onSaveFile,
              tooltip: 'Sauvegarder',
            ),
            IconButton(
              icon: const Icon(Icons.note_add_outlined, color: Colors.white),
              onPressed: onNewFile,
              tooltip: 'Nouveau fichier',
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: Colors.grey),
              onPressed: onClearCode,
              tooltip: 'Effacer le code',
            ),
          ],
          examplesMenu,
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.code, color: SenAlgoTheme.neonYellow),
            tooltip: 'Traduire en Python',
            onPressed: onShowPython,
          ),
          const SizedBox(width: 8),
          if (executionState.status == ExecutionStatus.stepping || executionState.status == ExecutionStatus.waitingForInput) ...[
            Center(
              child: SizedBox(
                height: 36,
                child: OutlinedButton.icon(
                  onPressed: onStop,
                  icon: const Icon(Icons.stop_circle_outlined, size: 16, color: Colors.redAccent),
                  label: isCompact
                      ? const SizedBox.shrink()
                      : Text(isMobile ? 'STOP' : 'ARRÊTER', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Center(
              child: SizedBox(
                height: 36,
                child: ElevatedButton.icon(
                  onPressed: executionState.status == ExecutionStatus.waitingForInput ? null : onStep,
                  icon: Icon(Icons.skip_next, size: 18, color: executionState.status == ExecutionStatus.waitingForInput ? Colors.grey : SenAlgoTheme.neonCyan),
                  label: isCompact
                      ? const SizedBox.shrink()
                      : Text('SUIVANT', style: TextStyle(color: executionState.status == ExecutionStatus.waitingForInput ? Colors.grey : SenAlgoTheme.neonCyan, fontWeight: FontWeight.bold, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (executionState.status == ExecutionStatus.waitingForInput ? Colors.grey : SenAlgoTheme.neonCyan).withValues(alpha: 0.1),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    side: BorderSide(color: (executionState.status == ExecutionStatus.waitingForInput ? Colors.grey : SenAlgoTheme.neonCyan).withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Center(
              child: SizedBox(
                height: 36,
                child: OutlinedButton.icon(
                  onPressed: executionState.status == ExecutionStatus.waitingForInput ? null : onToggleAutoPlay,
                  icon: Icon(autoPlayEnabled ? Icons.pause : Icons.play_circle_outline, size: 16, color: executionState.status == ExecutionStatus.waitingForInput ? Colors.grey : SenAlgoTheme.neonYellow),
                  label: isCompact
                      ? const SizedBox.shrink()
                      : Text('AUTO', style: TextStyle(color: executionState.status == ExecutionStatus.waitingForInput ? Colors.grey : SenAlgoTheme.neonYellow, fontWeight: FontWeight.bold, fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: autoPlayEnabled ? SenAlgoTheme.neonYellow.withValues(alpha: 0.2) : Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    side: BorderSide(color: (executionState.status == ExecutionStatus.waitingForInput ? Colors.grey : SenAlgoTheme.neonYellow).withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ),
          ] else
            Center(
              child: SizedBox(
                height: 36,
                child: OutlinedButton.icon(
                  onPressed: (executionState.status == ExecutionStatus.running) ? null : onRunStepByStep,
                  icon: Icon(Icons.bug_report_outlined, size: 16, color: (executionState.status == ExecutionStatus.running) ? Colors.grey : SenAlgoTheme.neonCyan),
                  label: isCompact
                      ? const SizedBox.shrink()
                      : Text('PAS À PAS', style: TextStyle(color: (executionState.status == ExecutionStatus.running) ? Colors.grey : SenAlgoTheme.neonCyan, fontWeight: FontWeight.bold, fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    side: BorderSide(color: (executionState.status == ExecutionStatus.running) ? Colors.grey : SenAlgoTheme.neonCyan.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ),
          const SizedBox(width: 8),
          Center(
            child: SizedBox(
              height: 36,
              child: ElevatedButton.icon(
                onPressed: (executionState.status == ExecutionStatus.running || executionState.status == ExecutionStatus.waitingForInput || executionState.status == ExecutionStatus.stepping)
                    ? null
                    : onRun,
                icon: Icon(Icons.play_arrow, size: 18, color: (executionState.status == ExecutionStatus.running || executionState.status == ExecutionStatus.waitingForInput || executionState.status == ExecutionStatus.stepping) ? Colors.grey : SenAlgoTheme.neonGreen),
                label: isCompact
                    ? const SizedBox.shrink()
                    : Text(isMobile ? 'RUN' : 'EXÉCUTER', style: TextStyle(color: (executionState.status == ExecutionStatus.running || executionState.status == ExecutionStatus.waitingForInput || executionState.status == ExecutionStatus.stepping) ? Colors.grey : SenAlgoTheme.neonGreen, fontWeight: FontWeight.bold, fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SenAlgoTheme.neonGreen.withValues(alpha: 0.1),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  side: BorderSide(color: (executionState.status == ExecutionStatus.running || executionState.status == ExecutionStatus.waitingForInput || executionState.status == ExecutionStatus.stepping) ? Colors.grey : SenAlgoTheme.neonGreen.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
    );
  }
}
