import 'package:flutter/material.dart';

// Extrait de main_screen.dart lors du decoupage : contenu inchange.

class ResizableSplitView extends StatefulWidget {
  final Widget child1;
  final Widget child2;
  final Axis axis;
  final double initialRatio;

  /// Taille minimale (en pixels) de chacun des deux panneaux. Exprimée en
  /// pixels et non en proportion : sur un petit écran, un minimum
  /// proportionnel laisserait des panneaux de quelques dizaines de pixels,
  /// donc illisibles.
  final double minPaneSize;

  const ResizableSplitView({
    super.key,
    required this.child1,
    required this.child2,
    this.axis = Axis.horizontal,
    this.initialRatio = 0.5,
    this.minPaneSize = 160,
  });

  @override
  State<ResizableSplitView> createState() => _ResizableSplitViewState();
}

class _ResizableSplitViewState extends State<ResizableSplitView> {
  /// Épaisseur de la poignée de redimensionnement.
  static const double _separatorThickness = 8;

  late double _ratio;

  /// Place réellement disponible pour les deux panneaux (poignée déduite) et
  /// minimum applicable, mémorisés à chaque layout pour que le glissement
  /// travaille dans les mêmes bornes que l'affichage.
  double _available = 0;
  double _effectiveMin = 0;

  @override
  void initState() {
    super.initState();
    _ratio = widget.initialRatio;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final total = widget.axis == Axis.horizontal ? constraints.maxWidth : constraints.maxHeight;
        // La poignée occupe de la place : l'oublier faisait dépasser la somme
        // des deux panneaux et donnait une contrainte négative à l'Expanded.
        _available = (total - _separatorThickness).clamp(0.0, double.infinity);
        // Sur un écran vraiment étroit, le minimum souhaité ne tient pas :
        // on se rabat sur un partage à parts égales plutôt que de déborder.
        _effectiveMin = widget.minPaneSize * 2 <= _available ? widget.minPaneSize : _available / 2;

        final firstSize = _clampFirstSize(_available * _ratio);

        return Flex(
          direction: widget.axis,
          children: [
            SizedBox(
              width: widget.axis == Axis.horizontal ? firstSize : null,
              height: widget.axis == Axis.vertical ? firstSize : null,
              child: widget.child1,
            ),
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanUpdate: (details) {
                setState(() {
                  final delta = widget.axis == Axis.horizontal ? details.delta.dx : details.delta.dy;
                  if (_available <= 0) return;
                  // On raisonne en pixels puis on repasse en proportion : le
                  // panneau suit le curseur au pixel près et s'arrête net sur
                  // les bornes au lieu d'accumuler un décalage.
                  _ratio = _clampFirstSize(_available * _ratio + delta) / _available;
                });
              },
              child: MouseRegion(
                cursor: widget.axis == Axis.horizontal ? SystemMouseCursors.resizeLeftRight : SystemMouseCursors.resizeUpDown,
                child: Container(
                  width: widget.axis == Axis.horizontal ? _separatorThickness : double.infinity,
                  height: widget.axis == Axis.vertical ? _separatorThickness : double.infinity,
                  color: Colors.transparent,
                  child: Center(
                    child: Container(
                      width: widget.axis == Axis.horizontal ? 2 : 30,
                      height: widget.axis == Axis.vertical ? 2 : 30,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: widget.child2,
            ),
          ],
        );
      },
    );
  }

  /// Ramène la taille du premier panneau dans les bornes autorisées. Appliqué
  /// aussi bien à l'affichage qu'au glissement, si bien qu'un
  /// redimensionnement de la fenêtre recale automatiquement un partage
  /// devenu impossible.
  double _clampFirstSize(double size) {
    if (_available <= 0) return 0;
    return size.clamp(_effectiveMin, _available - _effectiveMin);
  }
}
