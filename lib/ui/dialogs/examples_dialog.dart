import 'package:flutter/material.dart';
import '../examples/example_programs.dart';
import '../theme.dart';

Future<String?> showExamplesLibrary(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context, isScrollControlled: true, useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 720),
    builder: (context) => const _ExamplesLibrary(),
  );
}

class _ExamplesLibrary extends StatefulWidget {
  const _ExamplesLibrary();
  @override
  State<_ExamplesLibrary> createState() => _ExamplesLibraryState();
}

class _ExamplesLibraryState extends State<_ExamplesLibrary> {
  String _query = '';
  ExampleProgram? _selected;

  @override
  Widget build(BuildContext context) {
    final examples = kExamplePrograms.where((e) => e.title.toLowerCase().contains(_query.toLowerCase())).toList();
    return SizedBox(
      height: (MediaQuery.sizeOf(context).height * 0.82 - MediaQuery.viewInsetsOf(context).bottom).clamp(240.0, double.infinity),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(_selected?.title ?? 'Une idée pour commencer', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700))),
            IconButton(tooltip: 'Fermer les exemples', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
          ]),
          const SizedBox(height: 4),
          Text(_selected == null ? '${kExamplePrograms.length} programmes à explorer, comprendre et modifier.' : 'Explorez le code avant de le charger dans l’éditeur.', style: const TextStyle(color: SenAlgoTheme.muted, fontSize: 13, height: 1.5)),
          const SizedBox(height: 16),
          if (_selected == null) ...[
            TextField(onChanged: (value) => setState(() => _query = value), decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Rechercher un exemple')),
            const SizedBox(height: 12),
            Expanded(child: examples.isEmpty ? const Center(child: Text('Aucun exemple trouvé.')) : ListView.separated(
              itemCount: examples.length,
              separatorBuilder: (_, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final example = examples[index];
                return ListTile(
                  tileColor: SenAlgoTheme.raisedSurface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: const Icon(Icons.code_rounded, color: SenAlgoTheme.neonCyan),
                  title: Text(example.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text('${example.code.split('\n').length} lignes · Aperçu du programme', style: const TextStyle(fontSize: 12, color: SenAlgoTheme.muted)),
                  trailing: const Icon(Icons.arrow_forward_rounded, size: 18),
                  onTap: () { FocusManager.instance.primaryFocus?.unfocus(); setState(() => _selected = example); },
                );
              },
            )),
          ] else ...[
            Expanded(child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: SenAlgoTheme.darkBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: SenAlgoTheme.border)),
              child: SingleChildScrollView(child: SelectableText(_selected!.code, style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.65, color: SenAlgoTheme.ink))),
            )),
            const SizedBox(height: 12),
            const Text('Le chargement remplace le programme dans l’éditeur.', style: TextStyle(color: SenAlgoTheme.muted, fontSize: 12)),
            const SizedBox(height: 12),
            Row(children: [
              OutlinedButton(onPressed: () => setState(() => _selected = null), child: const Text('Retour')),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton.icon(onPressed: () => Navigator.pop(context, _selected!.code), icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Charger l’exemple'))),
            ]),
          ],
        ]),
      ),
    );
  }
}
