/// A single node in an evolution chain tree.
class EvolutionNode {
  final int speciesId;
  final String speciesName;
  final List<EvolutionDetail> details; // conditions to reach THIS node from parent
  final List<EvolutionNode> evolvesTo;

  const EvolutionNode({
    required this.speciesId,
    required this.speciesName,
    required this.details,
    required this.evolvesTo,
  });

  factory EvolutionNode.fromJson(Map<String, dynamic> json) {
    final speciesUrl = (json['species'] as Map)['url'] as String;
    final segments = Uri.parse(speciesUrl).pathSegments;
    final idStr = segments.lastWhere((s) => s.isNotEmpty);

    return EvolutionNode(
      speciesId: int.parse(idStr),
      speciesName: (json['species'] as Map)['name'] as String,
      details: (json['evolution_details'] as List)
          .map((d) => EvolutionDetail.fromJson(d as Map<String, dynamic>))
          .toList(),
      evolvesTo: (json['evolves_to'] as List)
          .map((e) => EvolutionNode.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  String get spriteUrl =>
      'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/$speciesId.png';

  String get displayName {
    return speciesName
        .split('-')
        .map((s) => s.isEmpty ? '' : '${s[0].toUpperCase()}${s.substring(1)}')
        .join(' ');
  }
}

class EvolutionDetail {
  final String trigger; // 'level-up', 'use-item', 'trade', 'shed', etc.
  final int? minLevel;
  final String? item;
  final String? heldItem;
  final int? minHappiness;
  final int? minBeauty;
  final int? minAffection;
  final String? timeOfDay; // 'day', 'night', ''
  final String? knownMove;
  final String? location;
  final bool? needsOverworldRain;
  final String? turnUpsideDown; // for Inkay

  const EvolutionDetail({
    required this.trigger,
    this.minLevel,
    this.item,
    this.heldItem,
    this.minHappiness,
    this.minBeauty,
    this.minAffection,
    this.timeOfDay,
    this.knownMove,
    this.location,
    this.needsOverworldRain,
    this.turnUpsideDown,
  });

  factory EvolutionDetail.fromJson(Map<String, dynamic> json) {
    return EvolutionDetail(
      trigger: (json['trigger'] as Map)['name'] as String,
      minLevel: json['min_level'] as int?,
      item: (json['item'] as Map?)?.isNotEmpty == true
          ? (json['item'] as Map)['name'] as String?
          : null,
      heldItem: (json['held_item'] as Map?)?.isNotEmpty == true
          ? (json['held_item'] as Map)['name'] as String?
          : null,
      minHappiness: json['min_happiness'] as int?,
      minBeauty: json['min_beauty'] as int?,
      minAffection: json['min_affection'] as int?,
      timeOfDay: json['time_of_day'] as String?,
      knownMove: (json['known_move'] as Map?)?.isNotEmpty == true
          ? (json['known_move'] as Map)['name'] as String?
          : null,
      location: (json['location'] as Map?)?.isNotEmpty == true
          ? (json['location'] as Map)['name'] as String?
          : null,
      needsOverworldRain: json['needs_overworld_rain'] as bool?,
      turnUpsideDown: json['turn_upside_down'] == true ? 'Turn upside down' : null,
    );
  }

  /// Human-readable condition summary.
  String get conditionLabel {
    final parts = <String>[];

    switch (trigger) {
      case 'level-up':
        if (minLevel != null) parts.add('Lv. $minLevel');
        if (minHappiness != null) parts.add('Friendship ≥ $minHappiness');
        if (minAffection != null) parts.add('Affection ≥ $minAffection');
        if (knownMove != null) parts.add('Knows ${_fmt(knownMove)}');
        if (location != null) parts.add('At ${_fmt(location)}');
        if (timeOfDay != null && timeOfDay!.isNotEmpty) parts.add('(${timeOfDay![0].toUpperCase()}${timeOfDay!.substring(1)})');
        if (turnUpsideDown != null) parts.add(turnUpsideDown!);
        if (needsOverworldRain == true) parts.add('(Rain)');
        if (parts.isEmpty) parts.add('Level up');
      case 'use-item':
        parts.add('Use ${_fmt(item ?? 'item')}');
      case 'trade':
        if (heldItem != null) {
          parts.add('Trade w/ ${_fmt(heldItem)}');
        } else {
          parts.add('Trade');
        }
      case 'shed':
        parts.add('Shed (Lv. 20 + empty slot)');
      default:
        parts.add(_fmt(trigger));
    }

    if (heldItem != null && trigger == 'level-up') {
      parts.add('Hold ${_fmt(heldItem)}');
    }

    return parts.join(', ');
  }

  static String _fmt(String? s) {
    if (s == null) return '';
    return s.split('-').map((p) => p.isEmpty ? '' : '${p[0].toUpperCase()}${p.substring(1)}').join(' ');
  }
}
