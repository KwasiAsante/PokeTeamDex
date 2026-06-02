import 'package:flutter/material.dart';
import 'package:poke_team_dex/services/format/format_service.dart';

enum MoveSpecialType { z, max, gmax }

/// Converts a PokéAPI or display move name to the PS id format used
/// in FormatService (lowercase, no hyphens or spaces).
String moveToPsId(String name) =>
    name.toLowerCase().replaceAll('-', '').replaceAll(' ', '');

/// Returns the special type classification for a move, or null if it
/// is a regular move.  G-Max is checked before Max because G-Max moves
/// are a subset of Max moves in the PS data.
MoveSpecialType? classifyMoveType(FormatService svc, String moveName) {
  final psId = moveToPsId(moveName);
  if (psId.startsWith('gmax')) return MoveSpecialType.gmax;
  final psMove = svc.moveDetail(psId);
  if (psMove?.isMaxMove == true) return MoveSpecialType.max;
  if (psMove?.isZMove == true) return MoveSpecialType.z;
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
