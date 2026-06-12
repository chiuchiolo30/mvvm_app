import 'package:equatable/equatable.dart';

import 'pokemon_list_item.dart';

class PokemonPage extends Equatable {
  const PokemonPage({
    required this.items,
    required this.nextOffset,
    required this.hasNextPage,
  });

  final List<PokemonListItem> items;
  final int? nextOffset;
  final bool hasNextPage;

  @override
  List<Object?> get props => [items, nextOffset, hasNextPage];
}
