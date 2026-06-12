class PokemonSummaryDto {
  const PokemonSummaryDto({required this.name, required this.url});

  final String name;
  final String url;

  factory PokemonSummaryDto.fromJson(Map<String, dynamic> json) {
    return PokemonSummaryDto(
      name: json['name'] as String,
      url: json['url'] as String,
    );
  }
}
