import 'package:flutter/material.dart';
import 'package:poke_team_dex/services/catalog/catalog_models.dart';

enum MoveSpecialType { z, max, gmax }

/// Converts a PokéAPI or display move name to the PS id format
/// (lowercase, no hyphens or spaces).
String moveToPsId(String name) =>
    name.toLowerCase().replaceAll('-', '').replaceAll(' ', '');

/// Returns the special type classification for [move], or null if it is a
/// regular move or not yet loaded. G-Max is checked before Max because
/// G-Max moves are a subset of Max moves in the catalog data.
MoveSpecialType? classifyMoveType(BackendMoveEntry? move) {
  if (move == null) return null;
  if (moveToPsId(move.name).startsWith('gmax')) return MoveSpecialType.gmax;
  if (move.isMaxMove) return MoveSpecialType.max;
  if (move.isZMove) return MoveSpecialType.z;
  return null;
}

/// Small coloured chip shown on Z-Moves, Max Moves, and G-Max Moves.
class MoveTypeChip extends StatelessWidget {
  final MoveSpecialType type;

  const MoveTypeChip({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (type) {
      MoveSpecialType.z    => ('Z',     const Color(0xFF7B2FBE), Colors.white),
      MoveSpecialType.max  => ('Max',   const Color(0xFFB71C1C), Colors.white),
      MoveSpecialType.gmax => ('G-Max', const Color(0xFFF57F17), Colors.white),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
      ),
    );
  }
}
