import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/get_pokemon_page_usecase.dart';
import 'pokemon_list_state.dart';

class PokemonListCubit extends Cubit<PokemonListState> {
  PokemonListCubit({required GetPokemonPageUseCase getPokemonPageUseCase})
    : _getPokemonPageUseCase = getPokemonPageUseCase,
      super(PokemonListState.initial());

  static const pageLimit = 20;

  final GetPokemonPageUseCase _getPokemonPageUseCase;

  Future<void> loadInitialPage() async {
    emit(state.loading());

    final result = await _getPokemonPageUseCase(
      const GetPokemonPageParams(limit: pageLimit, offset: 0),
    );

    result.fold((failure) => emit(state.failure(failure.message)), (page) {
      if (page.items.isEmpty) {
        emit(state.empty());
        return;
      }

      emit(
        state.success(
          items: page.items,
          nextOffset: page.nextOffset,
          hasNextPage: page.hasNextPage,
        ),
      );
    });
  }

  Future<void> loadNextPage() async {
    if (!state.canLoadNextPage) {
      return;
    }

    final offset = state.nextOffset;
    if (offset == null) {
      return;
    }

    emit(state.loadingMore());

    final result = await _getPokemonPageUseCase(
      GetPokemonPageParams(limit: pageLimit, offset: offset),
    );

    result.fold((failure) => emit(state.paginationFailure(failure.message)), (
      page,
    ) {
      emit(
        state.success(
          items: [...state.items, ...page.items],
          nextOffset: page.nextOffset,
          hasNextPage: page.hasNextPage,
        ),
      );
    });
  }

  Future<void> retry() => loadInitialPage();

  Future<void> retryNextPage() => loadNextPage();
}
