import 'pokemon_summary_dto.dart';

class PokemonPageDto {
  const PokemonPageDto({
    required this.count,
    required this.next,
    required this.previous,
    required this.results,
  });

  final int count;
  final String? next;
  final String? previous;
  final List<PokemonSummaryDto> results;

  factory PokemonPageDto.fromJson(Map<String, dynamic> json) {
    final resultsJson = json['results'] as List<dynamic>;

    return PokemonPageDto(
      count: json['count'] as int,
      next: json['next'] as String?,
      previous: json['previous'] as String?,
      results: resultsJson
          .map(
            (item) => PokemonSummaryDto.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}
