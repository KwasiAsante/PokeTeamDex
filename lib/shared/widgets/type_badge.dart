import 'package:flutter/material.dart';
import 'package:poke_team_dex/shared/theme/pokemon_type_colors.dart';

String _capitalize(String s) => s.isEmpty
    ? s
    : '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}';

class TypeBadge extends StatelessWidget {

  final String type;

  const TypeBadge({required this.type, super.key});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: PokemonTypeColors.colors[type.toLowerCase()] ?? PokemonTypeColors.colors['unknown']!,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _capitalize(type),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}