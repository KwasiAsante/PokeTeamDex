import 'package:flutter/material.dart';

/// A labelled horizontal stat bar for Pokémon base stats.
/// [label] is the short stat name (e.g. "HP", "Atk").
/// [value] is the base stat value (0–255).
/// [maxValue] is the scale ceiling — defaults to 255.
class StatBar extends StatelessWidget {
  final String label;
  final int value;
  final int maxValue;

  const StatBar({
    super.key,
    required this.label,
    required this.value,
    this.maxValue = 255,
  });

  Color _barColor() {
    final ratio = value / maxValue;
    if (ratio >= 0.7) return const Color(0xFF4CAF50); // green
    if (ratio >= 0.4) return const Color(0xFFFFC107); // amber
    return const Color(0xFFF44336);                   // red
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              label,
              style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              value.toString(),
              textAlign: TextAlign.end,
              style: textTheme.bodySmall,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (value / maxValue).clamp(0.0, 1.0),
                minHeight: 10,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(_barColor()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
