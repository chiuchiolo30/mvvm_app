import 'package:dartz/dartz.dart';

import '../entities/pokemon_page.dart';
import '../failures/pokemon_list_failure.dart';

abstract class PokemonListRepository {
  Future<Either<PokemonListFailure, PokemonPage>> getPokemonPage({
    required int limit,
    required int offset,
  });
}
