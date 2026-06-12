import 'package:equatable/equatable.dart';

class PokemonListItem extends Equatable {
  const PokemonListItem({
    required this.id,
    required this.displayName,
    required this.pokedexNumber,
    required this.artworkUrl,
  });

  final int id;
  final String displayName;
  final String pokedexNumber;
  final String artworkUrl;

  @override
  List<Object?> get props => [id, displayName, pokedexNumber, artworkUrl];
}
