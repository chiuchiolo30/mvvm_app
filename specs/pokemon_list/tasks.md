# Tasks: pokemon_list

> Ejecutar en orden. Cada bloque debe estar completo antes de pasar al siguiente.  
> Builder: seguir `specs/pokemon_list/plan.md` y `.ai/context/architecture.md`.

---

## Bloque 1 — Domain

- [x] Crear `PokemonListItem` en `domain/entities/pokemon_list_item.dart`.
- [x] Crear `PokemonPage` en `domain/entities/pokemon_page.dart`.
- [x] Crear `PokemonListFailure` y subtipos en `domain/failures/pokemon_list_failure.dart`.
- [x] Crear `PokemonListRepository` abstracto en `domain/repositories/pokemon_list_repository.dart`.
- [x] Crear `GetPokemonPageUseCase` y `GetPokemonPageParams` en `domain/usecases/get_pokemon_page_usecase.dart`.

---

## Bloque 2 — Data

- [x] Crear `PokemonSummaryDto` en `data/dtos/pokemon_summary_dto.dart`.
- [x] Crear `PokemonPageDto` en `data/dtos/pokemon_page_dto.dart`.
- [x] Crear `PokemonListRemoteDataSource` abstracto y `HttpPokemonListRemoteDataSource` en `data/datasources/pokemon_list_remote_datasource.dart`.
- [x] Crear mappers en `data/mappers/pokemon_page_mapper.dart`.
- [x] Crear `PokemonListRepositoryImpl` en `data/repositories/pokemon_list_repository_impl.dart`.

---

## Bloque 3 — UI

- [x] Crear `PokemonListState` y `PokemonListStatus` en `ui/cubit/pokemon_list_state.dart`.
- [x] Crear `PokemonListCubit` en `ui/cubit/pokemon_list_cubit.dart`.
- [x] Crear `PokemonListScreen` en `ui/screens/pokemon_list_screen.dart`.
- [x] Crear `PokemonListCard` en `ui/widgets/pokemon_list_card.dart`.
- [x] Crear `PokemonListLoadingView` en `ui/widgets/pokemon_list_loading_view.dart`.
- [x] Crear `PokemonListEmptyView` en `ui/widgets/pokemon_list_empty_view.dart`.
- [x] Crear `PokemonListErrorView` en `ui/widgets/pokemon_list_error_view.dart`.
- [x] Crear `PokemonListPaginationFooter` en `ui/widgets/pokemon_list_pagination_footer.dart`.
- [x] Asegurar estados: initial, loading, success, loadingMore, empty, failure, paginationFailure.
- [x] Asegurar placeholder de imagen para loading/error de artwork.

---

## Bloque 4 — DI

- [x] Agregar dependencias necesarias en `pubspec.yaml`: `http`, `dartz`, `equatable`, `flutter_bloc`, `get_it`.
- [x] Crear `lib/core/di/service_locator.dart` con `GetIt` centralizado.
- [x] Registrar `http.Client` con `registerLazySingleton`.
- [x] Registrar `PokemonListRemoteDataSource` con `registerLazySingleton`.
- [x] Registrar `PokemonListRepository` con `registerLazySingleton`.
- [x] Registrar `GetPokemonPageUseCase` con `registerFactory`.
- [x] Registrar `PokemonListCubit` con `registerFactory`.
- [x] Actualizar `main.dart` para configurar DI y mostrar `PokemonListScreen` mediante `BlocProvider` sin usar GetIt dentro de UI.

---

## Bloque 5 — Validacion

- [x] Ejecutar `flutter pub get`.
- [x] Ejecutar `dart format lib test` si existen cambios en esos paths.
- [x] Ejecutar `dart run tools/architecture_check.dart` y corregir cualquier violacion.
- [x] Ejecutar `dart run tools/technical_debt_metrics.dart --path lib` y revisar hotspots.
- [x] Comparar baseline si existe con `dart run tools/technical_debt_metrics.dart --path lib --compare-baseline`.
- [x] Exportar baseline por feature significativa con `dart run tools/technical_debt_metrics.dart --path lib --export-baseline` si no hay regresiones inaceptables.

---

## Bloque 6 — Review

- [x] Revisar implementacion contra `specs/pokemon_list/spec.md`.
- [x] Revisar implementacion contra `specs/pokemon_list/plan.md`.
- [x] Verificar tabla de cumplimiento AC1-AC10.
- [x] Decision: APPROVED.
