import 'package:equatable/equatable.dart';

import '../../domain/entities/pokemon_list_item.dart';

enum PokemonListStatus {
  initial,
  loading,
  success,
  loadingMore,
  empty,
  failure,
  paginationFailure,
}

class PokemonListState extends Equatable {
  const PokemonListState({
    required this.status,
    required this.items,
    required this.hasNextPage,
    this.nextOffset,
    this.failureMessage,
    this.paginationFailureMessage,
  });

  factory PokemonListState.initial() {
    return const PokemonListState(
      status: PokemonListStatus.initial,
      items: [],
      nextOffset: 0,
      hasNextPage: true,
    );
  }

  final PokemonListStatus status;
  final List<PokemonListItem> items;
  final int? nextOffset;
  final bool hasNextPage;
  final String? failureMessage;
  final String? paginationFailureMessage;

  bool get canLoadNextPage {
    return hasNextPage &&
        nextOffset != null &&
        status != PokemonListStatus.loading &&
        status != PokemonListStatus.loadingMore;
  }

  PokemonListState loading() {
    return const PokemonListState(
      status: PokemonListStatus.loading,
      items: [],
      nextOffset: 0,
      hasNextPage: true,
    );
  }

  PokemonListState success({
    required List<PokemonListItem> items,
    required int? nextOffset,
    required bool hasNextPage,
  }) {
    return PokemonListState(
      status: PokemonListStatus.success,
      items: items,
      nextOffset: nextOffset,
      hasNextPage: hasNextPage,
    );
  }

  PokemonListState loadingMore() {
    return PokemonListState(
      status: PokemonListStatus.loadingMore,
      items: items,
      nextOffset: nextOffset,
      hasNextPage: hasNextPage,
    );
  }

  PokemonListState empty() {
    return const PokemonListState(
      status: PokemonListStatus.empty,
      items: [],
      hasNextPage: false,
    );
  }

  PokemonListState failure(String message) {
    return PokemonListState(
      status: PokemonListStatus.failure,
      items: const [],
      nextOffset: 0,
      hasNextPage: true,
      failureMessage: message,
    );
  }

  PokemonListState paginationFailure(String message) {
    return PokemonListState(
      status: PokemonListStatus.paginationFailure,
      items: items,
      nextOffset: nextOffset,
      hasNextPage: hasNextPage,
      paginationFailureMessage: message,
    );
  }

  @override
  List<Object?> get props => [
    status,
    items,
    nextOffset,
    hasNextPage,
    failureMessage,
    paginationFailureMessage,
  ];
}
