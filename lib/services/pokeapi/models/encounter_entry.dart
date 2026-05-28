class EncounterEntry {
  final String locationAreaName;
  final List<VersionEncounter> versionDetails;

  const EncounterEntry({
    required this.locationAreaName,
    required this.versionDetails,
  });

  factory EncounterEntry.fromJson(Map<String, dynamic> json) {
    return EncounterEntry(
      locationAreaName: (json['location_area'] as Map)['name'] as String,
      versionDetails: (json['version_details'] as List)
          .map((v) => VersionEncounter.fromJson(v as Map<String, dynamic>))
          .toList(),
    );
  }

  String get displayName {
    return locationAreaName
        .split('-')
        .map((s) => s.isEmpty ? '' : '${s[0].toUpperCase()}${s.substring(1)}')
        .join(' ');
  }
}

class VersionEncounter {
  final String version;
  final int maxChance;
  final List<EncounterMethod> methods;

  const VersionEncounter({
    required this.version,
    required this.maxChance,
    required this.methods,
  });

  factory VersionEncounter.fromJson(Map<String, dynamic> json) {
    return VersionEncounter(
      version: (json['version'] as Map)['name'] as String,
      maxChance: json['max_chance'] as int,
      methods: (json['encounter_details'] as List)
          .map((e) => EncounterMethod.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  String get versionLabel {
    return version
        .split('-')
        .map((s) => s.isEmpty ? '' : '${s[0].toUpperCase()}${s.substring(1)}')
        .join(' ');
  }
}

class EncounterMethod {
  final String method;
  final int minLevel;
  final int maxLevel;
  final int chance;

  const EncounterMethod({
    required this.method,
    required this.minLevel,
    required this.maxLevel,
    required this.chance,
  });

  factory EncounterMethod.fromJson(Map<String, dynamic> json) {
    return EncounterMethod(
      method: (json['method'] as Map)['name'] as String,
      minLevel: json['min_level'] as int,
      maxLevel: json['max_level'] as int,
      chance: json['chance'] as int,
    );
  }

  String get methodLabel {
    return method
        .split('-')
        .map((s) => s.isEmpty ? '' : '${s[0].toUpperCase()}${s.substring(1)}')
        .join(' ');
  }

  String get levelRange =>
      minLevel == maxLevel ? 'Lv. $minLevel' : 'Lv. $minLevel–$maxLevel';
}
