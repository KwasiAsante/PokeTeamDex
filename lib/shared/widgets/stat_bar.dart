import 'package:flutter/material.dart';

/// A labelled horizontal stat bar for Pokémon base stats.
/// [label] is the short stat name (e.g. "HP", "Atk").
/// [value] is the base stat value (0–255).
/// [maxValue] is the scale ceiling — defaults to 255.
/// [delay] staggers the fill animation when multiple bars are rendered together.
class StatBar extends StatefulWidget {
  final String label;
  final int value;
  final int maxValue;
  final Duration delay;

  const StatBar({
    super.key,
    required this.label,
    required this.value,
    this.maxValue = 255,
    this.delay = Duration.zero,
  });

  @override
  State<StatBar> createState() => _StatBarState();
}

class _StatBarState extends State<StatBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 650),
      vsync: this,
    );
    _progress = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _barColor(double ratio) {
    if (ratio >= 0.7) return const Color(0xFF4CAF50); // green
    if (ratio >= 0.4) return const Color(0xFFFFC107); // amber
    return const Color(0xFFF44336); // red
  }

  @override
  Widget build(BuildContext context) {
    final ratio = (widget.value / widget.maxValue).clamp(0.0, 1.0);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              widget.label,
              style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              widget.value.toString(),
              textAlign: TextAlign.end,
              style: textTheme.bodySmall,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AnimatedBuilder(
              animation: _progress,
              builder: (_, _) => ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _progress.value * ratio,
                  minHeight: 10,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _barColor(_progress.value * ratio),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
