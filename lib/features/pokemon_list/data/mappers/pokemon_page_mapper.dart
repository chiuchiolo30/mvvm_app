import '../../domain/entities/pokemon_list_item.dart';
import '../../domain/entities/pokemon_page.dart';
import '../dtos/pokemon_page_dto.dart';
import '../dtos/pokemon_summary_dto.dart';

extension PokemonPageDtoMapper on PokemonPageDto {
  PokemonPage toDomain({required int currentOffset, required int limit}) {
    return PokemonPage(
      items: results.map((dto) => dto.toDomain()).toList(),
      nextOffset: next == null ? null : currentOffset + limit,
      hasNextPage: next != null,
    );
  }
}

extension PokemonSummaryDtoMapper on PokemonSummaryDto {
  PokemonListItem toDomain() {
    final id = _extractPokemonId(url);

    return PokemonListItem(
      id: id,
      displayName: _formatName(name),
      pokedexNumber: '#${id.toString().padLeft(3, '0')}',
      artworkUrl:
          'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/$id.png',
    );
  }
}

int _extractPokemonId(String url) {
  final segments = Uri.parse(
    url,
  ).pathSegments.where((segment) => segment.isNotEmpty).toList();
  final id = int.tryParse(segments.last);

  if (id == null) {
    throw FormatException('Could not extract Pokemon id from url: $url');
  }

  return id;
}

String _formatName(String name) {
  return name
      .split('-')
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}
