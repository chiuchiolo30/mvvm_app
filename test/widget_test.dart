import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mvvm_app/core/di/service_locator.dart';
import 'package:mvvm_app/features/pokemon_list/domain/entities/pokemon_page.dart';
import 'package:mvvm_app/features/pokemon_list/domain/failures/pokemon_list_failure.dart';
import 'package:mvvm_app/features/pokemon_list/domain/repositories/pokemon_list_repository.dart';
import 'package:mvvm_app/features/pokemon_list/domain/usecases/get_pokemon_page_usecase.dart';
import 'package:mvvm_app/features/pokemon_list/ui/cubit/pokemon_list_cubit.dart';
import 'package:mvvm_app/main.dart';

void main() {
  setUp(() async {
    await sl.reset();
    sl.registerFactory(
      () => PokemonListCubit(
        getPokemonPageUseCase: GetPokemonPageUseCase(_FakePokemonRepository()),
      ),
    );
  });

  testWidgets('shows pokemon list entrypoint', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.text('Pokemon'), findsOneWidget);
    expect(find.text('No hay Pokemon para mostrar'), findsOneWidget);
  });
}

class _FakePokemonRepository implements PokemonListRepository {
  @override
  Future<Either<PokemonListFailure, PokemonPage>> getPokemonPage({
    required int limit,
    required int offset,
  }) async {
    return const Right(
      PokemonPage(items: [], nextOffset: null, hasNextPage: false),
    );
  }
}
