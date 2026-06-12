import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../entities/pokemon_page.dart';
import '../failures/pokemon_list_failure.dart';
import '../repositories/pokemon_list_repository.dart';

class GetPokemonPageUseCase {
  const GetPokemonPageUseCase(this._repository);

  final PokemonListRepository _repository;

  Future<Either<PokemonListFailure, PokemonPage>> call(
    GetPokemonPageParams params,
  ) {
    return _repository.getPokemonPage(
      limit: params.limit,
      offset: params.offset,
    );
  }
}

class GetPokemonPageParams extends Equatable {
  const GetPokemonPageParams({required this.limit, required this.offset});

  final int limit;
  final int offset;

  @override
  List<Object?> get props => [limit, offset];
}
