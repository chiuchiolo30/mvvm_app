# Plan Tecnico: pokemon_list

> Generado/validado por: architect.agent.md  
> Basado en: specs/pokemon_list/spec.md  
> Contexto leido: architecture.md, conventions.md, design.md

---

## Resumen de arquitectura

La feature `pokemon_list` muestra una lista paginada de Pokemon obtenida desde PokeAPI. La pantalla carga la primera pagina al abrirse, renderiza tarjetas con nombre formateado, numero de Pokedex y artwork oficial, y solicita paginas adicionales al acercarse al final del scroll.

El flujo respeta Clean Architecture feature-first:

```txt
PokemonListScreen
  -> PokemonListCubit
    -> GetPokemonPageUseCase
      -> PokemonListRepository
        -> PokemonListRepositoryImpl
          -> PokemonListRemoteDataSource
            -> PokeAPI
```

---

## Capas involucradas

```txt
lib/
  features/
    pokemon_list/
      domain/
        entities/
        repositories/
        usecases/
        failures/
      data/
        datasources/
        dtos/
        mappers/
        repositories/
      ui/
        screens/
        widgets/
        cubit/
      di/
```

---

## Domain Design

### Entidades

| Entity | Campos clave |
|---|---|
| `PokemonListItem` | `id`, `displayName`, `pokedexNumber`, `artworkUrl` |
| `PokemonPage` | `items`, `nextOffset`, `hasNextPage` |

`PokemonListItem` representa el item visible de negocio para el listado. No conoce JSON, DTOs ni detalles de HTTP.

`PokemonPage` representa una pagina de resultados ya traducida al lenguaje de la aplicacion.

### Repository (abstracto)

```dart
abstract class PokemonListRepository {
  Future<Either<PokemonListFailure, PokemonPage>> getPokemonPage({
    required int limit,
    required int offset,
  });
}
```

### UseCases

| UseCase | Input | Output |
|---|---|---|
| `GetPokemonPageUseCase` | `GetPokemonPageParams(limit, offset)` | `Either<PokemonListFailure, PokemonPage>` |

### Failures

```dart
sealed class PokemonListFailure extends Equatable {
  const PokemonListFailure();

  String get message;
}
```

| Failure | Uso |
|---|---|
| `PokemonListNetworkFailure` | API inaccesible, timeout o error HTTP |
| `PokemonListUnexpectedFailure` | parsing invalido o error no esperado |

---

## Data Design

### DTOs

| DTO | Campos | Fuente |
|---|---|---|
| `PokemonPageDto` | `count`, `next`, `previous`, `results` | `GET /pokemon` |
| `PokemonSummaryDto` | `name`, `url` | `results[]` |

La respuesta de PokeAPI se mantiene encapsulada en Data. Ningun DTO cruza hacia Domain o UI.

### DataSources

| DataSource | Tipo | Metodo |
|---|---|---|
| `PokemonListRemoteDataSource` | remote abstract | `getPokemonPage({required int limit, required int offset})` |
| `HttpPokemonListRemoteDataSource` | remote implementation | HTTP GET a `https://pokeapi.co/api/v2/pokemon` |

### RepositoryImpl

`PokemonListRepositoryImpl` implementa `PokemonListRepository`, invoca el datasource, convierte DTOs a entidades mediante mappers y traduce excepciones tecnicas a `PokemonListFailure`.

### Mappers

| Mapper | Responsabilidad |
|---|---|
| `PokemonPageDtoMapper` | convertir pagina DTO a `PokemonPage`, calcular `hasNextPage` y `nextOffset` |
| `PokemonSummaryDtoMapper` | extraer ID desde `url`, formatear nombre, formatear numero de Pokedex y construir `artworkUrl` |

Reglas de negocio aplicadas por mapper:

- Reemplazar guiones por espacios y capitalizar cada palabra.
- Formatear numero como `#001`, `#025`, etc.
- Construir artwork con `https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/{id}.png`.
- Usar `next == null` para determinar fin de paginacion.

---

## UI Design

### Screen

- Nombre: `PokemonListScreen`
- Cubit: `PokemonListCubit`
- Responsabilidad: renderizar estados, mantener `ScrollController`, disparar paginacion al acercarse al final.

### Widgets

| Widget | Responsabilidad |
|---|---|
| `PokemonListCard` | tarjeta con artwork, nombre y numero |
| `PokemonListLoadingView` | loading estructurado inicial |
| `PokemonListEmptyView` | mensaje guia para lista vacia |
| `PokemonListErrorView` | error inicial con retry |
| `PokemonListPaginationFooter` | spinner inferior o retry inline |

### Estados

```dart
enum PokemonListStatus {
  initial,
  loading,
  success,
  loadingMore,
  empty,
  failure,
  paginationFailure,
}
```

Campos de estado:

| Campo | Uso |
|---|---|
| `status` | estado explicito de UI |
| `items` | Pokemon visibles |
| `nextOffset` | offset de la siguiente pagina |
| `hasNextPage` | evita pedir paginas cuando `next == null` |
| `failureMessage` | mensaje para error inicial |
| `paginationFailureMessage` | mensaje para retry inline |

Transiciones principales:

- `initial -> loading -> success | empty | failure`
- `success -> loadingMore -> success | paginationFailure`
- `paginationFailure -> loadingMore -> success | paginationFailure`

---

## Integracion con otras features

- Depende de: ninguna feature existente.
- Afecta a: `main.dart`, que usara la pantalla como entry point inicial.
- Requiere DI centralizada para registrar HTTP client, datasource, repository, use case y cubit.

---

## Decisiones tecnicas

- Usar Cubit porque el flujo es lineal: cargar primera pagina, cargar mas, reintentar.
- Mantener formato de nombre, numero y artwork en Data mapper para que UI no contenga reglas de negocio.
- Registrar Cubit con `registerFactory` para evitar estado persistente entre instancias.
- Usar `Theme.of(context)` como fuente visual porque el proyecto no tiene Design System propio aun.
- Agregar dependencias minimas: `http`, `dartz`, `equatable`, `flutter_bloc`, `get_it`.

---

## Riesgos

- La spec indica estado `Draft`, pero el usuario explicito que debe usarse como spec aprobada.
- El proyecto parte del template counter de Flutter, por lo que la implementacion debe crear la estructura base de app y DI.
- No existe baseline actual en `.ai/architecture-baselines/`; despues de implementar se debe ejecutar debt metrics y exportar baseline si corresponde.

---

## Validacion de arquitectura

- [x] UI no importa Data.
- [x] Domain no depende de infraestructura.
- [x] DTOs no salen de Data.
- [x] UseCases usan repository abstracto.
- [x] Either con L concreto como subtipo de Failure.
- [x] Cubit no usa DataSource ni RepositoryImpl.
- [x] GetIt no se usa dentro de UI, Bloc o Cubit.
- [x] Cubit se registra como factory, no singleton.

---

## Spec Traceability

| Acceptance Criterion | Elemento de diseno |
|---|---|
| AC1 | `PokemonListCubit.loadInitialPage()` llama `GetPokemonPageUseCase(limit: 20, offset: 0)` |
| AC2 | `PokemonListCard` renderiza `displayName` y `artworkUrl` |
| AC3 | Scroll listener dispara `loadNextPage()` con guard contra requests en vuelo |
| AC4 | `PokemonListStatus.loading` muestra loading inicial sin lista ni error |
| AC5 | `PokemonListStatus.loadingMore` mantiene lista y muestra footer spinner |
| AC6 | `PokemonListStatus.failure` muestra mensaje humano y retry |
| AC7 | `PokemonListStatus.paginationFailure` mantiene lista y muestra retry inline |
| AC8 | Primera pagina sin resultados emite `PokemonListStatus.empty` |
| AC9 | `hasNextPage == false` detiene paginacion silenciosamente |
| AC10 | `PokemonListCard` usa placeholder con `errorBuilder` si falla imagen |

Criterios no cubiertos: ninguno.
