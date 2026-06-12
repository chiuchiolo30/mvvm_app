import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/pokemon_list_cubit.dart';
import '../cubit/pokemon_list_state.dart';
import '../widgets/pokemon_list_card.dart';
import '../widgets/pokemon_list_empty_view.dart';
import '../widgets/pokemon_list_error_view.dart';
import '../widgets/pokemon_list_loading_view.dart';
import '../widgets/pokemon_list_pagination_footer.dart';

class PokemonListScreen extends StatefulWidget {
  const PokemonListScreen({super.key});

  @override
  State<PokemonListScreen> createState() => _PokemonListScreenState();
}

class _PokemonListScreenState extends State<PokemonListScreen> {
  static const _loadMoreThreshold = 360.0;

  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    context.read<PokemonListCubit>().loadInitialPage();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    final position = _scrollController.position;
    final isNearEnd =
        position.maxScrollExtent - position.pixels <= _loadMoreThreshold;

    if (isNearEnd) {
      context.read<PokemonListCubit>().loadNextPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pokemon')),
      body: BlocBuilder<PokemonListCubit, PokemonListState>(
        builder: (context, state) {
          return switch (state.status) {
            PokemonListStatus.initial ||
            PokemonListStatus.loading => const PokemonListLoadingView(),
            PokemonListStatus.empty => PokemonListEmptyView(
              onRetry: context.read<PokemonListCubit>().retry,
            ),
            PokemonListStatus.failure => PokemonListErrorView(
              message: state.failureMessage ?? 'No pudimos cargar los Pokemon.',
              onRetry: context.read<PokemonListCubit>().retry,
            ),
            PokemonListStatus.success ||
            PokemonListStatus.loadingMore ||
            PokemonListStatus.paginationFailure => _PokemonGrid(
              scrollController: _scrollController,
              state: state,
            ),
          };
        },
      ),
    );
  }
}

class _PokemonGrid extends StatelessWidget {
  const _PokemonGrid({required this.scrollController, required this.state});

  final ScrollController scrollController;
  final PokemonListState state;

  @override
  Widget build(BuildContext context) {
    final showFooter =
        state.status == PokemonListStatus.loadingMore ||
        state.status == PokemonListStatus.paginationFailure;
    final itemCount = state.items.length + (showFooter ? 1 : 0);

    return GridView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        childAspectRatio: 0.82,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        if (index >= state.items.length) {
          return PokemonListPaginationFooter(
            isLoading: state.status == PokemonListStatus.loadingMore,
            errorMessage: state.paginationFailureMessage,
            onRetry: context.read<PokemonListCubit>().retryNextPage,
          );
        }

        return PokemonListCard(pokemon: state.items[index]);
      },
    );
  }
}
