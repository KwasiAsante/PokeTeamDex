import 'package:change_case/change_case.dart';

class PokemonListEntry {
  final int id;
  final String name;
  final String url;
  Map<String, dynamic> sprites = {};
  List<dynamic> types = [];

  PokemonListEntry({required this.id, required this.name, required this.url});

  factory PokemonListEntry.fromJson(Map<String, dynamic> json) {
    var s = Uri.parse(json['url'] as String);
    var sp = s.pathSegments.last.isEmpty ? s.pathSegments[s.pathSegments.length - 2] : s.pathSegments.last;

    var entry = PokemonListEntry(
      id: int.parse(sp),
      name: json['name'],
      url: json['url'],
    );

    if (json.containsKey('sprites')) {
      entry.sprites = json['sprites'];
    }

    if (json.containsKey('types')) {
      entry.types = json['types'];
    }

    return entry;
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'url': url,
    };
  }

  String get displayName => "#${displayId()} - ${name.toCapitalCase()}";
  String displayId() => id.toString().padLeft(3, '0');

  String _getOfficalArtwork() {
    if (sprites.isNotEmpty && sprites.containsKey('other')) {
      Map<String, dynamic> other = sprites['other'];
      if (other.containsKey('official-artwork')) {
        String? artwork = other['official-artwork']['front_default'];
        return artwork ?? '';
      }
    }

    return '';
  }

  String get imageUrl {
    String url = _getOfficalArtwork();
    return url.isNotEmpty
    ? url
    : "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/$id.png";
  }
}