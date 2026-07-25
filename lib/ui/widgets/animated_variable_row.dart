import 'package:flutter/material.dart';

import '../theme.dart';

// Extrait de main_screen.dart lors du decoupage : contenu inchange.

class AnimatedVariableRow extends StatefulWidget {
  final String name;
  final dynamic value;

  const AnimatedVariableRow({super.key, required this.name, required this.value});

  @override
  State<AnimatedVariableRow> createState() => _AnimatedVariableRowState();
}

class _AnimatedVariableRowState extends State<AnimatedVariableRow> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1));
    _colorAnimation = ColorTween(
      begin: SenAlgoTheme.neonGreen.withValues(alpha: 0.4),
      end: Colors.transparent,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(AnimatedVariableRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatValue(dynamic value) {
    if (value is String) {
      return '"$value"';
    } else if (value is bool) {
      return value ? 'Vrai' : 'Faux';
    }
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _colorAnimation,
      builder: (context, child) {
        return Container(
          color: _colorAnimation.value,
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  widget.name,
                  style: const TextStyle(color: SenAlgoTheme.neonCyan, fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: Text(
                  _formatValue(widget.value),
                  style: const TextStyle(color: SenAlgoTheme.neonGreen, fontSize: 12, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
