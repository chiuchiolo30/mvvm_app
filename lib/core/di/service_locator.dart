import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;

import '../../features/pokemon_list/data/datasources/pokemon_list_remote_datasource.dart';
import '../../features/pokemon_list/data/repositories/pokemon_list_repository_impl.dart';
import '../../features/pokemon_list/domain/repositories/pokemon_list_repository.dart';
import '../../features/pokemon_list/domain/usecases/get_pokemon_page_usecase.dart';
import '../../features/pokemon_list/ui/cubit/pokemon_list_cubit.dart';

final sl = GetIt.instance;

Future<void> configureDependencies() async {
  sl.registerLazySingleton<http.Client>(http.Client.new);

  sl.registerLazySingleton<PokemonListRemoteDataSource>(
    () => HttpPokemonListRemoteDataSource(sl()),
  );

  sl.registerLazySingleton<PokemonListRepository>(
    () => PokemonListRepositoryImpl(remoteDataSource: sl()),
  );

  sl.registerFactory(() => GetPokemonPageUseCase(sl()));

  sl.registerFactory(() => PokemonListCubit(getPokemonPageUseCase: sl()));
}
