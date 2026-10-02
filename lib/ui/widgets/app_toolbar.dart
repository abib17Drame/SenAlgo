import 'package:flutter/material.dart';

import '../../state/execution_provider.dart';
import '../theme.dart';

/// Toutes les commandes appellent les actions détenues par l'écran.
class AppToolbar extends StatelessWidget implements PreferredSizeWidget {
  final bool isMobile;
  final bool isCompact;
  final ExecutionState executionState;
  final bool autoPlayEnabled;
  final Widget examplesMenu;
  final VoidCallback onOpenFile;
  final VoidCallback onSaveFile;
  final VoidCallback onNewFile;
  final VoidCallback onClearCode;
  final VoidCallback onShowPython;
  final VoidCallback onStop;
  final VoidCallback onStep;
  final VoidCallback onToggleAutoPlay;
  final VoidCallback onRunStepByStep;
  final VoidCallback onRun;
  final VoidCallback? onShowHelp;

  const AppToolbar({
    super.key, required this.isMobile, required this.isCompact,
    required this.executionState, required this.autoPlayEnabled,
    required this.examplesMenu, required this.onOpenFile,
    required this.onSaveFile, required this.onNewFile,
    required this.onClearCode, required this.onShowPython,
    required this.onStop, required this.onStep,
    required this.onToggleAutoPlay, required this.onRunStepByStep,
    required this.onRun, this.onShowHelp,
  });

  @override
  Size get preferredSize => Size.fromHeight(isMobile ? 124 : 72);

  void _showTools(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (sheetContext) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Votre espace de travail', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text('Les outils pour écrire, enregistrer et apprendre.', style: TextStyle(color: SenAlgoTheme.muted)),
            const SizedBox(height: 20),
            _tool(sheetContext, Icons.note_add_outlined, 'Nouveau fichier', 'Partir d’un programme modèle', onNewFile),
            _tool(sheetContext, Icons.folder_open_outlined, 'Ouvrir un fichier .algo', 'Retrouver un programme sur votre appareil', onOpenFile),
            _tool(sheetContext, Icons.save_outlined, 'Sauvegarder', 'Exporter votre programme en fichier .algo', onSaveFile),
            const Divider(height: 24),
            _tool(sheetContext, Icons.code_rounded, 'Traduire en Python', 'Voir et copier le programme traduit', onShowPython),
            if (onShowHelp != null)
              _tool(sheetContext, Icons.school_outlined, 'Guide du langage', 'Syntaxe, saisie et raccourcis', onShowHelp!),
            const Divider(height: 24),
            _tool(sheetContext, Icons.delete_sweep_outlined, 'Effacer le code', 'Vider l’éditeur', () async {
              final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
                title: const Text('Effacer le programme ?'),
                content: const Text('Le contenu de l’éditeur sera supprimé. Pensez à sauvegarder votre fichier.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Annuler')),
                  TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Effacer')),
                ],
              ));
              if (confirmed == true) onClearCode();
            }, destructive: true),
          ],
        ),
      ),
    );
  }

  Widget _tool(BuildContext context, IconData icon, String title, String subtitle, VoidCallback action, {bool destructive = false}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: SenAlgoTheme.raisedSurface, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: destructive ? Colors.redAccent : SenAlgoTheme.neonCyan, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(color: SenAlgoTheme.muted, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
      onTap: () { Navigator.pop(context); action(); },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: isMobile ? 64 : 72,
      titleSpacing: 16,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              'assets/icon/icon_256.png',
              width: 36,
              height: 36,
              fit: BoxFit.contain,
              semanticLabel: 'Logo SenAlgo',
            ),
          ),
          const SizedBox(width: 10),
          Flexible(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('SenAlgo', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.8)),
              if (!isCompact) const Text('L’algorithmique prend vie.', style: TextStyle(fontSize: 10, color: SenAlgoTheme.muted)),
            ],
          )),
        ],
      ),
      actions: [
        if (!isMobile && MediaQuery.sizeOf(context).width >= 1100) ...[
          IconButton(tooltip: 'Ouvrir un fichier .algo', onPressed: onOpenFile, icon: const Icon(Icons.folder_open_outlined, size: 21)),
          IconButton(tooltip: 'Sauvegarder', onPressed: onSaveFile, icon: const Icon(Icons.save_outlined, size: 21)),
        ],
        examplesMenu,
        if (!isMobile && MediaQuery.sizeOf(context).width >= 1100) IconButton(tooltip: 'Traduire en Python', onPressed: onShowPython, icon: const Icon(Icons.code_rounded, size: 21)),
        IconButton(tooltip: 'Outils du programme', onPressed: () { FocusManager.instance.primaryFocus?.unfocus(); _showTools(context); }, icon: const Icon(Icons.more_horiz_rounded)),
        if (!isMobile) ...[
          const SizedBox(width: 10),
          _executionControls(context),
        ],
        const SizedBox(width: 12),
      ],
      bottom: isMobile ? PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: _executionControls(context)),
      ) : null,
    );
  }

  Widget _executionControls(BuildContext context) {
    final status = executionState.status;
    final active = status == ExecutionStatus.running || status == ExecutionStatus.stepping || status == ExecutionStatus.waitingForInput;
    final stepping = status == ExecutionStatus.stepping || status == ExecutionStatus.waitingForInput;
    final waiting = status == ExecutionStatus.waitingForInput;
    Widget command(Widget button) => isMobile ? Expanded(child: button) : button;
    final controls = <Widget>[
      if (active) ...[
        command(OutlinedButton.icon(
          onPressed: onStop, icon: const Icon(Icons.stop_rounded, size: 19),
          label: Text(isMobile ? 'Arrêter' : 'ARRÊTER', maxLines: 1, overflow: TextOverflow.ellipsis),
          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFFF9B9B), padding: EdgeInsets.symmetric(horizontal: isMobile && isCompact ? 8 : 12)),
        )),
        const SizedBox(width: 8),
      ],
      if (stepping) ...[
        command(OutlinedButton.icon(
          onPressed: waiting ? null : onToggleAutoPlay,
          icon: Icon(autoPlayEnabled ? Icons.pause_rounded : Icons.slow_motion_video_rounded, size: 18),
          label: Text(isMobile ? (autoPlayEnabled ? 'Pause' : 'Auto') : 'AUTO'),
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10), backgroundColor: autoPlayEnabled ? SenAlgoTheme.neonYellow.withValues(alpha: 0.12) : null),
        )),
        const SizedBox(width: 8),
        command(ElevatedButton.icon(
          onPressed: waiting ? null : onStep,
          icon: const Icon(Icons.skip_next_rounded, size: 19),
          label: Text(isMobile ? 'Suivant' : 'SUIVANT', maxLines: 1, overflow: TextOverflow.ellipsis),
          style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(horizontal: isMobile && isCompact ? 8 : 12)),
        )),
      ] else ...[
        // La commande reste visible sur ordinateur pendant l'exécution.
        if (!active || !isMobile) ...[
          command(OutlinedButton.icon(
            onPressed: active ? null : onRunStepByStep,
            icon: const Icon(Icons.account_tree_outlined, size: 18),
            label: Text(isMobile ? 'Pas à pas' : 'PAS À PAS'),
            style: OutlinedButton.styleFrom(padding: EdgeInsets.symmetric(horizontal: isMobile && isCompact ? 8 : 12)),
          )),
          const SizedBox(width: 8),
        ],
        command(ElevatedButton.icon(
          onPressed: active ? null : onRun,
          icon: const Icon(Icons.play_arrow_rounded, size: 20),
          label: Text(active && isMobile ? 'En cours' : (isMobile ? 'Exécuter' : 'EXÉCUTER')),
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14)),
        )),
      ],
    ];
    return Row(mainAxisSize: isMobile ? MainAxisSize.max : MainAxisSize.min, children: controls);
  }
}
