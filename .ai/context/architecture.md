# ARCHITECTURE CONTRACT (STRICT)

## Purpose

This document defines the mandatory architectural rules for Flutter projects built under Clean Architecture, a feature-first approach, and enterprise maintainability standards.

Any developer or AI agent working on the project must follow the same approach to building features, separating responsibilities, naming components, and avoiding unnecessary coupling.

---

## Core Principles

The architecture must prioritize:

- maintainability;
- testability;
- low coupling;
- high cohesion;
- clear separation of responsibilities;
- independence between UI, domain, and data;
- feature scalability;
- ease of working in a monorepo;
- consistency across modules;
- explicit code over "magic" code.

The primary rule is:

```txt
UI → Domain → Data
UI must never access Data directly.
```

---

## Primary Architectural Style

The project uses:

```txt
Clean Architecture + Feature-First + Lightweight DDD
```

The main structure must be organized by functional features.

Example:

```txt
lib/
  features/
    auth/
      domain/
      data/
      ui/

    menu_selection/
      domain/
      data/
      ui/

    branches/
      domain/
      data/
      ui/
```

- Each feature must be as independent as possible.
- A feature must be able to evolve without breaking other features.

---

## Allowed Layers

Each feature may have these layers:

```
feature/
  domain/
  data/
  ui/
  di/
```

`presentation/` may be used instead of `ui/`, or `infrastructure/` instead of `data/`, if the project already uses them — but only one convention must be maintained within the same project.

---

## MVVM Mapping

This project is described in MVVM terms. The Clean Architecture layers above map directly onto MVVM roles — there is no separate pattern to learn or implement:

| MVVM Role | Project Equivalent |
|---|---|
| **View** | Screens and Widgets (`ui/screens`, `ui/widgets`) |
| **ViewModel** | Cubit / Bloc (`ui/cubit`, `ui/bloc`) |
| **Model** | Domain (Entities, UseCases, Repositories) + Data (DTOs, DataSources, RepositoryImpl) |

### Rules

- The Cubit/Bloc **is** the ViewModel: it holds and exposes presentation state, reacts to actions from the View, and orchestrates the Model through UseCases.
- Do **not** create a separate `XxxViewModel` class alongside a Cubit/Bloc — that would duplicate the same responsibility and violate the "no parallel patterns" rule (section 14).
- Everything this document says about Cubit/Bloc (responsibilities, state design, communication rules, DI lifecycle in section 5) applies to "the ViewModel" without changes.
- When asked for "the ViewModel of feature X", the answer is the Cubit/Bloc in `features/x/ui/cubit` (or `bloc`).

---

# 1. Domain Layer

### Responsibility

The `domain` layer contains the business rules and primary contracts of the feature.

It must be the most stable layer.

It must not depend on Flutter, Supabase, Firebase, Dio, SQLite, SharedPreferences, external APIs, or any technical details.

### May contain

```
domain/
  entities/
  repositories/
  usecases/
  failures/
  value_objects/
  events/
```

Example:

```
domain/
  entities/
    menu_combination.dart

  repositories/
    menu_repository.dart

  usecases/
    get_published_menus_usecase.dart
    select_menu_combination_usecase.dart

  failures/
    menu_failure.dart
```

## Mandatory Domain Rules

- Domain does not import Data.
- Domain does not import UI.
- Domain does not know DTOs.
- Domain does not know API responses.
- Domain does not know widgets.
- Domain does not know Cubits or Blocs.
- Domain must not depend on infrastructure packages.
- Domain defines contracts, not implementations.
- Use cases must express business actions.
- Repositories in Domain are abstractions.

## Entities

Entities represent business concepts.

Example:

```dart
class MenuCombination extends Equatable {
  const MenuCombination({
    required this.id,
    required this.mainDish,
    required this.sideDish,
    required this.availableDate,
  });

  final String id;
  final Product mainDish;
  final Product? sideDish;
  final DateTime availableDate;

  @override
  List<Object?> get props => [
        id,
        mainDish,
        sideDish,
        availableDate,
      ];
}
```

### Rules:

- Entities must be simple.
- They must represent business language.
- They must avoid technical details.
- They must not use JSON annotations.
- They must not depend on DTOs.
- They may use `Equatable`.
- Do not use `freezed` in entities by default, unless explicitly decided for the project.

## Abstract Repositories

Abstract repositories live in Domain.

Example:

```dart
abstract class MenuRepository {
  Future<Either<MenuFailure, List<MenuCombination>>> getPublishedMenus({
    required DateTime date,
  });

  Future<Either<MenuFailure, Unit>> selectCombination({
    required String combinationId,
  });
}
```

### Rules:

- The contract speaks in business language.
- Returns entities, value objects, or domain types.
- Never returns DTOs.
- Never returns raw responses.
- Never exposes Supabase, Dio, Firebase, SQLite, or external details.

## UseCases

Use cases represent business actions and may extend a base interface.

Example:

```dart
abstract class UseCase<Type, Params> {
  Future<Either<Failure, Type>> call(Params params);
}

class GetFoodProvidersRatingUsecase
    implements UseCase<List<FoodProvider>, NoParams> {
  GetFoodProvidersRatingUsecase(this.hr);
  final HomeRepository hr;

  @override
  Future<Either<Failure, List<FoodProvider>>> call(NoParams n) =>
      hr.getFoodProvidersRating();
}
```

### Rules:

- A use case must have a single, clear responsibility.
- Must depend on abstract repositories.
- Must return `Either<Failure, T>` when errors are possible.
- Must not access datasources directly.
- Must not contain UI logic.
- Must not handle navigation.
- Must not display messages.
- Must not import Flutter widgets.

### UseCase Naming

Use semantic, action-oriented names.

#### Good examples:

```
SignInUseCase
GetCurrentUserProfileUseCase
GetPublishedMenusUseCase
SelectMenuCombinationUseCase
ValidateTokenUseCase
RefreshTokenUseCase
GetEnabledBranchesUseCase
```

#### Bad examples:

```
MenuUseCase
DataUseCase
CallApiUseCase
ProcessUseCase
HandleUseCase
```

---

# 2. Data Layer

### Responsibility

The `data` layer contains concrete implementations, API integration, local storage, DTOs, mappers, and datasources.

Data knows technical details.

Domain must not know Data.

### May contain

```
data/
  datasources/
  sources/
  sources/api/
  sources/database/
  sources/remote/
  dtos/
  models/
  mappers/
  repositories/
```

Example:

```
data/
  datasources/
    menu_remote_datasource.dart
    menu_local_datasource.dart

  dtos/
    menu_combination_dto.dart

  mappers/
    menu_combination_mapper.dart

  repositories/
    menu_repository_impl.dart
```

### Mandatory Data Rules

- Data may import Domain.
- Data implements repositories defined in Domain.
- Data contains DTOs and mappers.
- Data may use Supabase, Dio, Firebase, SQLite, SharedPreferences, etc.
- Data must not import UI.
- Data must not depend on Cubits or Blocs.
- Data must not emit visual states.
- Data must not handle navigation.
- Data must not show SnackBars, dialogs, or loaders.

### RepositoryImpl

Example:

```dart
class MenuRepositoryImpl implements MenuRepository {
  const MenuRepositoryImpl({
    required MenuRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  final MenuRemoteDataSource _remoteDataSource;

  @override
  Future<Either<MenuFailure, List<MenuCombination>>> getPublishedMenus({
    required DateTime date,
  }) async {
    try {
      final dtos = await _remoteDataSource.getPublishedMenus(date: date);

      final entities = dtos
          .map((dto) => dto.toDomain())
          .toList();

      return Right(entities);
    } catch (error, stackTrace) {
      return Left(MenuFailure.unexpected(
        error: error,
        stackTrace: stackTrace,
      ));
    }
  }
}
```

### Rules:

- RepositoryImpl translates technical errors into domain Failures.
- RepositoryImpl converts DTOs to Entities.
- RepositoryImpl must not return DTOs.
- RepositoryImpl must not expose raw exceptions.
- RepositoryImpl must not contain UI logic.

### Datasources

Datasources are responsible for communicating with external sources.

Example:

```dart
abstract class MenuRemoteDataSource {
  Future<List<MenuCombinationDto>> getPublishedMenus({
    required DateTime date,
  });
}
```

Implementation:

```dart
class SupabaseMenuRemoteDataSource implements MenuRemoteDataSource {
  const SupabaseMenuRemoteDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<List<MenuCombinationDto>> getPublishedMenus({
    required DateTime date,
  }) async {
    final response = await _client
        .from('vw_published_menus')
        .select()
        .eq('published_date', date.toIso8601String());

    return response
        .map(MenuCombinationDto.fromJson)
        .toList();
  }
}
```

### Rules:

- Datasource may throw technical exceptions.
- Datasource must not return entities.
- Datasource returns DTOs or technical models.
- Datasource does not decide business rules.
- Datasource does not handle navigation.
- Datasource does not show visual errors.

### DTOs

DTOs represent the shape of external data.

Example:

```dart
class MenuCombinationDto {
  const MenuCombinationDto({
    required this.id,
    required this.mainDishName,
    required this.availableDate,
  });

  final String id;
  final String mainDishName;
  final String availableDate;

  factory MenuCombinationDto.fromJson(Map<String, dynamic> json) {
    return MenuCombinationDto(
      id: json['id'] as String,
      mainDishName: json['main_dish_name'] as String,
      availableDate: json['available_date'] as String,
    );
  }
}
```

### Rules:

- DTOs may use freezed, json_serializable, or manual models.
- DTOs live in Data.
- DTOs must not reach UI.
- DTOs must not be used by UseCases.
- DTOs must be mapped to entities.

### Mappers

Mappers transform DTOs into entities and vice versa when needed.

Example:

```dart
extension MenuCombinationDtoMapper on MenuCombinationDto {
  MenuCombination toDomain() {
    return MenuCombination(
      id: id,
      mainDish: Product(name: mainDishName),
      sideDish: null,
      availableDate: DateTime.parse(availableDate),
    );
  }
}
```

### Rules:

- The mapper must be close to Data.
- The mapper may import Domain.
- The mapper must not import UI.
- The mapper must isolate technical API inconsistencies from the domain.

---

# 3. UI / Presentation Layer

### Responsibility

The `ui` or `presentation` layer contains screens, widgets, Cubits, Blocs, states, and events.

Its responsibility is to present information and react to user interactions.

It does not contain deep business rules.

### May contain

```
ui/
  screens/
  widgets/
  cubit/
  bloc/
  state/
```

Example:

```
ui/
  screens/
    menu_selection_screen.dart

  widgets/
    menu_combination_card.dart
    menu_empty_state.dart
    menu_loading_view.dart

  cubit/
    menu_selection_cubit.dart
    menu_selection_state.dart
```

### Mandatory UI Rules

- UI must not import Data.
- UI must not use Datasources.
- UI must not use RepositoryImpl.
- UI must not use DTOs.
- UI must not call APIs directly.
- UI must communicate through Cubit/Bloc.
- Cubit/Bloc calls UseCases.
- Widgets must not contain business logic.
- Widgets must be small and composable.
- Screens must delegate visual components to widgets.
- UI must handle loading, empty, error, and success states.

## Correct Flow

```
Screen
  → Cubit/Bloc
    → UseCase
      → Abstract Repository
        → RepositoryImpl
          → DataSource
            → API / DB / Local Storage
```

## Forbidden Flow

```
Screen
  → RepositoryImpl

Screen
  → DataSource

Widget
  → SupabaseClient

Cubit
  → DTO

UseCase
  → DataSource
```

---

# 4. Bloc / Cubit

### Preference

Use `Cubit` for simple and medium-complexity flows.

Use `Bloc` when:

- there are many explicit events;
- the feature has multiple event inputs;
- the flow needs to audit actions;
- complex states are derived from multiple events.

### Cubit Responsibility

The Cubit coordinates the UI with the use cases.

It may:

- call use cases;
- manage states;
- transform domain results into visual state;
- handle domain errors for the UI to present;
- prepare data for the screen.

It must not:

- call datasources;
- call APIs directly;
- use DTOs;
- contain infrastructure logic;
- manage fine visual details;
- build widgets.

### State

States must be explicit.

Example:

```dart
class MenuSelectionState extends Equatable {
  const MenuSelectionState({
    required this.status,
    required this.combinations,
    this.selectedCombination,
    this.failureMessage,
  });

  factory MenuSelectionState.initial() {
    return const MenuSelectionState(
      status: MenuSelectionStatus.initial,
      combinations: [],
    );
  }

  final MenuSelectionStatus status;
  final List<MenuCombination> combinations;
  final MenuCombination? selectedCombination;
  final String? failureMessage;

  MenuSelectionState loading() {
    return copyWith(status: MenuSelectionStatus.loading);
  }

  MenuSelectionState success({
    required List<MenuCombination> combinations,
  }) {
    return copyWith(
      status: MenuSelectionStatus.success,
      combinations: combinations,
      failureMessage: null,
    );
  }

  MenuSelectionState failure(String message) {
    return copyWith(
      status: MenuSelectionStatus.failure,
      failureMessage: message,
    );
  }

  MenuSelectionState copyWith({
    MenuSelectionStatus? status,
    List<MenuCombination>? combinations,
    MenuCombination? selectedCombination,
    String? failureMessage,
  }) {
    return MenuSelectionState(
      status: status ?? this.status,
      combinations: combinations ?? this.combinations,
      selectedCombination: selectedCombination ?? this.selectedCombination,
      failureMessage: failureMessage ?? this.failureMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        combinations,
        selectedCombination,
        failureMessage,
      ];
}
```

### Rules:

- State must be immutable.
- Use Equatable.
- Avoid ambiguous states.
- Prefer explicit transitions.
- Avoid relying solely on a generic `copyWith` to express important state changes.
- Use factories or semantic methods when they improve clarity.

### Status

Use clear enums.

Example:

```dart
enum MenuSelectionStatus {
  initial,
  loading,
  success,
  empty,
  failure,
}
```

### Rules:

- Do not use strings for states.
- Do not mix loading with success.
- Do not represent errors with loose booleans.
- State must allow rendering the UI without complex logic in the widget.

### Cubit Example

```dart
class MenuSelectionCubit extends Cubit<MenuSelectionState> {
  MenuSelectionCubit({
    required GetPublishedMenusUseCase getPublishedMenusUseCase,
    required SelectMenuCombinationUseCase selectMenuCombinationUseCase,
  })  : _getPublishedMenusUseCase = getPublishedMenusUseCase,
        _selectMenuCombinationUseCase = selectMenuCombinationUseCase,
        super(MenuSelectionState.initial());

  final GetPublishedMenusUseCase _getPublishedMenusUseCase;
  final SelectMenuCombinationUseCase _selectMenuCombinationUseCase;

  Future<void> loadMenus({
    required DateTime date,
  }) async {
    emit(state.loading());

    final result = await _getPublishedMenusUseCase(date: date);

    result.fold(
      (failure) {
        emit(state.failure(failure.message));
      },
      (combinations) {
        if (combinations.isEmpty) {
          emit(state.copyWith(status: MenuSelectionStatus.empty));
          return;
        }

        emit(state.success(combinations: combinations));
      },
    );
  }

  Future<void> selectCombination(String combinationId) async {
    emit(state.copyWith(status: MenuSelectionStatus.loading));

    final result = await _selectMenuCombinationUseCase(
      combinationId: combinationId,
    );

    result.fold(
      (failure) => emit(state.failure(failure.message)),
      (_) => emit(state.copyWith(status: MenuSelectionStatus.success)),
    );
  }
}
```

## 4.1 Communication Between Blocs / Cubits

Blocs and Cubits must not know each other directly.

### Allowed

- `BlocListener` in the UI that reacts to a Bloc's state and dispatches an event to another.
- A shared UseCase called independently by two different Blocs.
- The `EventBus` from the `core_domain` package to emit domain events that multiple Blocs can listen to.

### Forbidden

- Receiving another Bloc as a constructor parameter of a Bloc.
- Calling `sl.get<AnotherBloc>()` inside an event handler.
- Adding events to another Bloc directly (`otherBloc.add(...)`) from inside a Bloc.
- Mutating the state of a Bloc from another Bloc.

Correct example:

```dart
// In the UI, BlocListener coordinates two Blocs without coupling them
BlocListener<ScannerBloc, ScannerState>(
  listener: (context, state) {
    if (state is ScannerSuccess) {
      context.read<ProductBloc>().add(LoadProduct(state.barcode));
    }
  },
  child: ...,
)
```

Forbidden example:

```dart
// ❌ Bloc injecting another Bloc in its constructor
class ProductDimensionsBloc extends Bloc<...> {
  final ProductListBloc productListBloc; // forbidden

  void _onSave(SaveEvent event, Emitter emit) {
    productListBloc.add(ModifyProductEvent(...)); // forbidden
  }
}
```

---

# 5. Dependency Injection

### Recommended Tool

Use `get_it`.

Injection must respect this order:

```txt
clients
  → datasources
    → repositories
      → usecases
        → cubits/blocs
```

Example:

```dart
final sl = GetIt.instance;

Future<void> configureDependencies() async {
  // Clients
  sl.registerLazySingleton<SupabaseClient>(
    () => Supabase.instance.client,
  );

  // Datasources
  sl.registerLazySingleton<MenuRemoteDataSource>(
    () => SupabaseMenuRemoteDataSource(sl()),
  );

  // Repositories
  sl.registerLazySingleton<MenuRepository>(
    () => MenuRepositoryImpl(remoteDataSource: sl()),
  );

  // UseCases
  sl.registerFactory(
    () => GetPublishedMenusUseCase(sl()),
  );

  sl.registerFactory(
    () => SelectMenuCombinationUseCase(sl()),
  );

  // Cubits
  sl.registerFactory(
    () => MenuSelectionCubit(
      getPublishedMenusUseCase: sl(),
      selectMenuCombinationUseCase: sl(),
    ),
  );
}
```

### Rules:

- Do not manually instantiate use cases inside widgets.
- Do not manually instantiate repositories inside Cubits.
- Do not register implementations before their dependencies.
- Do not use the service locator directly in Domain.
- Avoid `GetIt.I()` inside business logic.
- Dependency composition must be centralized.

## GetIt Registration Lifecycle

The registration type determines the instance lifecycle. Misusing it causes silent state bugs.

```
Blocs and Cubits         → registerFactory        (fresh state on each use)
UseCases                 → registerFactory        (stateless, cheap to create)
RepositoryImpl           → registerLazySingleton  (stateless, 1 instance is enough)
DataSources              → registerLazySingleton  (stateless)
HTTP/Supabase clients    → registerLazySingleton  (1 global connection)
Stateless services       → registerLazySingleton
```

### Lifecycle Rules

- `registerLazySingleton(() => XxxBloc(...))` **is forbidden**. A singleton Bloc persists its state across navigations and user sessions.
- `registerSingleton` for Blocs or Cubits **is forbidden** for the same reason.
- Blocs and Cubits must be created with `registerFactory` to guarantee a clean initial state each time the screen instantiates them.
- Use `BlocProvider` in the widget tree — not `sl.get<XxxBloc>()` inside `initState` or `build()`.

Correct example:

```dart
// DI
sl.registerFactory(
  () => MenuSelectionCubit(
    getPublishedMenusUseCase: sl(),
    selectMenuCombinationUseCase: sl(),
  ),
);

// Router or parent screen
BlocProvider(
  create: (_) => sl<MenuSelectionCubit>(),
  child: MenuSelectionScreen(),
)
```

Forbidden example:

```dart
// ❌ Bloc as singleton — state is never reset
sl.registerLazySingleton(() => MenuSelectionCubit(...));

// ❌ GetIt inside initState or build
@override
void initState() {
  super.initState();
  _cubit = sl.get<MenuSelectionCubit>(); // forbidden
}
```

---

# 6. Routing

### Responsibility

Routing must handle navigation, not business logic.

Preference:

```txt
GoRouter
```

`go_router_builder` may be used if the project requires it.

### Rules

- Routes must be declarative.
- Do not pass complex objects through routes unnecessarily.
- Avoid relying on `history.state` for critical information.
- For session data, prefer controlled storage or global state.
- Role-based navigation must be decided using authenticated profile information.
- Guards must be simple and predictable.

Role-based navigation example:

```
auth success
  → fetch profile
    → role == company_admin
      → CompanyAdminHomeScreen
    → role == employee
      → EmployeeHomeScreen
    → role == guest
      → GuestHomeScreen
```

---

# 7. Design System and UI

### Primary Rule

All UI must respect the project's Design System.

The UI must not feel like a demo.

It must feel:

```
enterprise
mobile-first
modern
clean
consistent
robust
```

### Mandatory Rules

- Use the application theme.
- Use Design System tokens.
- Use `DSResponsive` for dimensions when available.
- Do not hardcode colors.
- Do not hardcode sizes when tokens are available.
- Do not create isolated styles if a component or token already exists.
- Design all states:
  - initial;
  - loading;
  - empty;
  - error;
  - success.
- Loading must reflect the real process when there are steps.
- Empty states must guide the user.
- Error states must allow recovery.
- Cards must have clear visual hierarchy.
- Forms must have clear validation.
- Buttons must have disabled/loading states.
- Widgets must be reusable.

### Forbidden in UI

- Putting business logic inside `build`.
- Making HTTP calls from a widget.
- Querying Supabase/Firebase/Dio directly from UI.
- Creating loose colors without a token.
- Duplicating existing Design System components.
- Using technical text for user-facing errors.
- Building screens without empty/error/loading states.

---

# 8. Error Handling

### Recommended Pattern

Use Failure in Domain.

Example:

```dart
sealed class MenuFailure extends Equatable {
  const MenuFailure();

  String get message;

  @override
  List<Object?> get props => [];
}

class MenuNetworkFailure extends MenuFailure {
  const MenuNetworkFailure();

  @override
  String get message => 'We could not load the menus. Check your connection.';
}

class MenuUnexpectedFailure extends MenuFailure {
  const MenuUnexpectedFailure({
    this.error,
    this.stackTrace,
  });

  final Object? error;
  final StackTrace? stackTrace;

  @override
  String get message => 'An unexpected error occurred.';
}
```

### Rules:

- Data captures technical errors.
- Data transforms technical errors into Failures.
- Domain exposes Failures.
- Cubit translates Failures into states.
- UI shows understandable messages.
- Do not show stack traces to the user.
- Do not leak technical exceptions into the UI.

## Typed Either — Mandatory Rule

Every `Either` representing a business result **must have its left type bound to `Failure`**.

```dart
// Correct — the compiler guarantees L is a concrete Failure
Future<Either<MenuFailure, List<MenuCombination>>> getPublishedMenus();
Future<Either<Failure, User>> login(Credentials creds);

// Forbidden — free generics nullify the contract
Future<Either<L, R>> call<L, R>();  // L can be any type
Future<Either<dynamic, dynamic>> call();
```

### Rules:

- `L` in `Either<L, R>` **must always** be a subtype of `Failure` from the `core_domain` package.
- **Forbidden**: `Either<L, R>` with `L` and `R` as unbound type parameters in UseCases, Repositories, and DataSources.
- The Cubit must be able to call `.fold((Failure f) ..., (T value) ...)` with type safety and without casts.

---

# 9. Testing

### Test Priority

```
UseCases
Repositories
Cubits/Blocs
Mappers
Critical Widgets
```

### UseCase Tests

Validate:

- that they call the correct repository;
- that they propagate Right correctly;
- that they propagate Left correctly;
- that they do not depend on Data.

### RepositoryImpl Tests

Validate:

- that it invokes the datasource;
- that it converts DTOs to entities;
- that it translates errors to Failures;
- that it does not expose raw exceptions.

### Cubit Tests

Validate:

- initial state;
- loading;
- success;
- empty;
- failure;
- state sequence;
- behavior on errors.

### Rules

- Use clear mocks/fakes.
- Do not test irrelevant details.
- Do not depend on real external services.
- Tests must document behavior, not accidental implementation.

---

# 10. Monorepo

### Compatibility

The architecture must adapt to monorepos with apps and packages.

Example:

```
apps/
  lunch_flow_app/

packages/
  core_network/
  core_storage/
  design_system/
  core_domain/
  lint_rules/
```

### Monorepo Rules

- Apps consume packages.
- Shared packages must not depend on apps.
- `design_system` must not depend on features.
- `core_network` must not depend on UI.
- `core_domain` must not depend on Data.
- Reusable features may live as a package when there is a real need for reuse.
- Do not move a feature to a package before a real reuse need exists.

### Allowed Dependencies

```
app
  → features
  → design_system
  → core packages
```

```
feature
  → core_domain
  → core_failure
```

### Forbidden Dependencies

```
design_system → app
core_network → ui
core_domain → data
domain → supabase
domain → dio
ui → datasource
ui → repository_impl
```

---

# 11. Naming Conventions

### Files

Use snake_case.

```
get_published_menus_usecase.dart
menu_repository_impl.dart
menu_remote_datasource.dart
menu_selection_cubit.dart
menu_selection_state.dart
```

### Classes

Use PascalCase.

```
GetPublishedMenusUseCase
MenuRepositoryImpl
MenuRemoteDataSource
MenuSelectionCubit
MenuSelectionState
```

### Variables and Methods

Use lowerCamelCase.

```
getPublishedMenus
selectedCombination
isPrimaryBranch
```

### Expected Suffixes

```
UseCase         (PascalCase in class, _usecase.dart in file)
Repository
RepositoryImpl
RemoteDataSource
LocalDataSource
Dto
Mapper
Cubit
Bloc
State
Event
Failure
```

### UseCase Naming Consistency Rule

- The class always ends in `UseCase` (PascalCase): `GetPublishedMenusUseCase`.
- The file always ends in `_usecase.dart` (snake_case): `get_published_menus_usecase.dart`.
- **Forbidden** to mix `Usecase`, `usecase`, and `UseCase` in the same project.
- Names must be semantic and action-oriented. See examples in section 1.

---

# 12. Anti-Coupling Rules

## Prohibition of Static Global Access

Static access to configuration, preferences, or environment variables inside internal layers violates Dependency Inversion and makes code untestable.

### Forbidden in Domain and Data

```dart
// ❌ Static access in DataSource
final branchId = PreferencesApp.sucursal; // forbidden
final url = dotenv.env['SERVER_URL']!;    // forbidden
final dni = SharedPreferences.getString('dni'); // forbidden
```

### Correct Approach

Define an interface in Domain or in the shared package and inject it:

```dart
// Domain or core_domain
abstract class IUserSession {
  String get sucursal;
  String get dni;
}

// Data — DataSource receives the interface via constructor
class StockApiDatasourceImpl implements StockApiDatasource {
  const StockApiDatasourceImpl({
    required this.http,
    required this.session,
  });

  final DioAdapter http;
  final IUserSession session;

  @override
  Future<Either<StockFailure, List<Article>>> getAll() async {
    final data = {'branch_id': session.sucursal};
    // ...
  }
}
```

### Critical Rule

UI does not access Data.

These imports are forbidden:

```dart
import 'package:app/features/menu/data/repositories/menu_repository_impl.dart';
import 'package:app/features/menu/data/datasources/menu_remote_datasource.dart';
import 'package:app/features/menu/data/dtos/menu_combination_dto.dart';
```

Inside any of:

```
ui/
presentation/
screens/
widgets/
cubit/
bloc/
```

### Also Forbidden

Domain importing Data:

```dart
import '../../data/...';
```

Data importing UI:

```dart
import '../../ui/...';
```

Core packages importing features:

```dart
import 'package:app/features/...';
```

---

# 13. Fitness Functions

Architectural rules are **automatically verified** through two complementary mechanisms:

## 13.1 Validation Script (`tools/architecture_check.dart`)

Run with:

```bash
dart run tools/architecture_check.dart
```

Returns exit code 1 if violations are found, enabling CI integration. Validates:

### Rule 1 — UI cannot import Data

```
No file under */ui/**/*.dart may import from */data/
```

### Rule 2 — Domain cannot import Data or UI

```
No file under */domain/**/*.dart may import from */data/ or */ui/
```

### Rule 3 — Data cannot import UI

```
No file under */data/**/*.dart may import from */ui/ or */presentation/
```

### Rule 4 — DTOs cannot appear outside Data

```
Classes with the Dto suffix may only exist inside */data/
```

### Rule 5 — RepositoryImpl cannot be used from UI

```
Classes with the RepositoryImpl suffix cannot be imported by UI
```

### Rule 6 — GetIt is forbidden in UI/Bloc

```
Calls to sl.get<> or sl() cannot appear in files under */ui/, */screens/, */widgets/, */cubit/, */bloc/
```

### Rule 7 — Blocs cannot be registered as LazySingleton

```
registerLazySingleton with a factory returning a Bloc or Cubit type is forbidden
```

### Rule 8 — Either with free generics is forbidden in Domain and Data

```
The pattern Either<L, R> with free type parameters cannot appear in */domain/ or */data/
```

### Rule 9 — UseCase files must follow naming convention (AST)

```
Files named *_usecase.dart must declare a class ending in UseCase
```

### Rule 10 — RepositoryImpl must implement a Repository (AST)

```
Classes ending in RepositoryImpl must implement at least one interface ending in Repository
```

### Rule 11 — Cubit/Bloc must not depend on other Cubit/Bloc in constructor (AST)

```
Constructor parameters of a Cubit/Bloc class must not be of type Cubit or Bloc
```

### Rule 12 — Datasource must not return Entity types (AST)

```
Methods in classes ending in DataSource must not return Entity types
```

## 13.2 Real-Time Lint Rules (`packages/lint_rules`)

The `lint_rules` package uses `custom_lint` to surface errors directly in the IDE and in `dart analyze`.

Activate in each app's `analysis_options.yaml`:

```yaml
analyzer:
  plugins:
    - custom_lint
custom_lint:
  rules:
    - avoid_get_it_in_ui
    - avoid_bloc_as_lazy_singleton
    - avoid_untyped_either
    - avoid_direct_bloc_dependency
```

Available rules:

| Rule | Detects | Severity |
|---|---|---|
| `avoid_get_it_in_ui` | `sl.get<>()` in UI/Bloc/Cubit files | error |
| `avoid_bloc_as_lazy_singleton` | `registerLazySingleton` returning Bloc/Cubit | warning |
| `avoid_untyped_either` | `Either<L, R>` with free generics | error |
| `avoid_direct_bloc_dependency` | Field of type Bloc/Cubit inside another Bloc/Cubit | warning |

---

# 13.3 Technical Debt Metrics (`tools/technical_debt_metrics.dart`)

Run with:

```bash
dart run tools/technical_debt_metrics.dart --path lib
```

Always exits 0 (reporting only — does not block CI). Produces a structured report per scope.

> **Single-package note**: this project has no `apps/`/`packages/` monorepo layout. Always pass `--path lib` to scope the report to application code. Without `--path`, the tool scans the entire repository — including `tools/` itself — as scope `monorepo`, which produces misleading results (the governance scripts' own complexity gets reported as project debt). `--path lib` resolves to scope `unknown`, which is evaluated against the `monorepo` policy thresholds (see 13.4).

### Metrics collected

| Metric | Description |
|---|---|
| LOC | Lines of code (non-blank, non-comment) |
| Classes | Number of class declarations |
| Functions | Number of method/function declarations |
| CC | Cyclomatic Complexity (per function) |
| CogC | Cognitive Complexity — Sonar/Richards model (per function) |
| Nesting | Max nesting depth (per function) |
| Ca | Afferent coupling — inbound imports (functional / technical split) |
| Ce | Efferent coupling — outbound imports |
| I | Instability = Ce / (Ca + Ce) |
| A | Abstractness = abstract classes / total classes |
| D | Distance from Main Sequence = \|A + I − 1\| (interpreted by Policy Engine) |
| Hotspots | Functions with highest CC + CogC + Nesting combined score |

### Scopes

| Scope | Example |
|---|---|
| `feature` | A single feature package |
| `app` | An app package |
| `package` | A shared package |
| `appsGroup` | All apps |
| `packagesGroup` | All packages |
| `monorepo` | Entire repository |

### Thresholds

**CC:** ✅ 0–10 / ⚠️ 11–15 / ❌ 16–24 / 🚨 25+

**CogC:** ✅ 0–10 / ⚠️ 11–20 / ❌ 21–30 / 🚨 31+

**Nesting:** ✅ 0–3 / ⚠️ 4–5 / ❌ 6–7 / 🚨 8+

---

# 13.4 Policy Engine

The Policy Engine applies context-aware thresholds to metrics. Default policy file: `.ai/architecture-policies.yaml`.

```bash
dart run tools/technical_debt_metrics.dart --path lib --policy .ai/architecture-policies.yaml
```

### Policy scopes

Each scope (`feature`, `app`, `package`, `monorepo`) may define independent thresholds for:

- `cc.warning`, `cc.error`
- `cogc.warning`, `cogc.error`
- `nesting.warning`, `nesting.error`
- `instability.warning`, `instability.error`
- `abstraction.distance.warning`, `abstraction.distance.error`, `abstraction.distance.mode`

### Enforcement modes

| Mode | Behavior |
|---|---|
| `reportOnly` | Prints policy evaluation, never fails |
| `failOnError` | Exits non-zero when any error threshold is exceeded |
| `failOnRegression` | Exits non-zero only when a metric regressed vs. baseline |

Default: `reportOnly` for all scopes.

### Distance interpretation

`D` (distance from Main Sequence) is **not** evaluated with fixed global thresholds. Its interpretation is delegated entirely to the Policy Engine per scope. Example: `feature.abstraction.distance.mode = informational` means D is shown but never flagged.

---

# 13.5 Evolutionary Baselines

Baselines capture a metric snapshot for comparison over time.

```bash
# Export a baseline
dart run tools/technical_debt_metrics.dart --path lib --export-baseline

# Compare against a baseline
dart run tools/technical_debt_metrics.dart --path lib --compare-baseline
```

### Baseline storage

```
.ai/architecture-baselines/
  features/
    <app-name>/
      <feature-name>.metrics.json
  apps/
    <app-name>.metrics.json
  packages/
    <package-name>.metrics.json
  monorepo.metrics.json
```

### Baseline format (v1)

```json
{
  "version": 1,
  "scope": "feature",
  "name": "signature_capture",
  "exportedAt": "2026-05-01T00:00:00Z",
  "metrics": { "loc": 712, "cc_avg": 3.2, "cogc_max": 25, ... },
  "hotspots": [
    { "function": "_SignatureCaptureViewState::build", "cc": 12, "cogc": 25, "nesting": 4 }
  ]
}
```

### Delta report

The comparison shows 12-metric diffs plus hotspot changes with directional indicators (▲ regression / ▼ improvement / = unchanged).

---

# 13.6 Spec-Driven Development

Spec-Driven Development (SDD) is the practice of writing an explicit, reviewable specification before implementation begins. It is not a documentation exercise — it is the primary context source for AI agents and human developers.

## Principle

```
spec → plan → tasks → implementation → validation
```

Never implement against a verbal requirement.  
Always implement against a written, approved spec.

## Feature Levels

| Level | Required files |
|---|---|
| Quick | `spec.md`, `tasks.md` |
| Standard | `spec.md`, `plan.md`, `tasks.md`, `quickstart.md` |
| Complex | Standard + optional `research.md`, `data-model.md`, `contracts/` |

## File Structure

```
specs/
  <app_name>/
    <feature_name>/
      spec.md
      plan.md
      tasks.md
      quickstart.md

  templates/
    spec.template.md
    plan.md
    tasks.md
    quickstart.md
```

## Integration with AI Agents

| Agent | Reads | Produces |
|---|---|---|
| `architect.agent.md` | `spec.md` + context files | `plan.md` |
| `feature-builder.agent.md` | `plan.md` + `tasks.md` + context files | Implementation |
| `reviewer.agent.md` | `spec.md` + `plan.md` + context files | Review with spec compliance table |

## Integration with Governance

- `plan.md` must reference the current baseline from `.ai/architecture-baselines/`.
- `tasks.md` must include a validation block: `check:arch` + `check:debt` + baseline comparison.
- `quickstart.md` must cover all acceptance criteria from `spec.md` as test scenarios.
- Reviewer must produce a spec compliance table mapping each criterion to an implementation status.

---

# 14. Rules for AI Agents

When an agent works on this project it must:

- read this file before modifying any code;
- respect the existing structure;
- not invent new architecture;
- not rename folders without justification;
- not move logic between layers without explaining why;
- not touch Data when the task is UI-only;
- not touch UI when the task is Domain/Data-only;
- not create DTOs in UI;
- not create business logic in widgets;
- not create circular dependencies;
- not hardcode visual styles;
- not replace existing patterns with personal preferences;
- not write "demo" code in production screens.

---

# 15. Pre-Completion Checklist

Before considering a feature done, validate:

```
[ ] UI does not import Data.
[ ] Domain does not import Data or UI.
[ ] Data does not import UI.
[ ] UseCases depend on abstract repositories.
[ ] RepositoryImpl implements a Domain repository.
[ ] DTOs do not leave Data.
[ ] There are mappers between DTOs and Entities.
[ ] Cubit/Bloc does not call datasources.
[ ] UI handles loading, empty, error, and success states.
[ ] Technical errors are transformed into Failures.
[ ] Either<L, R> uses a concrete L as a subtype of Failure (no free generics).
[ ] Dependency injection respects the correct order.
[ ] Blocs and Cubits registered with registerFactory, not registerLazySingleton.
[ ] No sl.get<>() inside Blocs, Cubits, Screens, or Widgets.
[ ] No static access to PreferencesApp/dotenv inside Domain or Data.
[ ] Blocs do not have direct dependencies on other Blocs in their constructor.
[ ] Names follow conventions (UseCase suffix in PascalCase, _usecase.dart file).
[ ] No heavy business logic in widgets.
[ ] No hardcoded styles when a Design System exists.
[ ] Tests exist at least for critical use cases, cubits, or repositories.
[ ] dart run tools/architecture_check.dart passes with no errors.
[ ] dart run tools/technical_debt_metrics.dart reviewed — no unacceptable regressions vs. baseline.
```

---

# 16. Default Decisions

When in doubt, apply these decisions:

```
Simple state               → Cubit
Complex/event-driven state → Bloc
External data              → DataSource
Business rule              → UseCase
Business contract          → Abstract Repository
Technical implementation   → RepositoryImpl
API ↔ Domain transform     → Mapper
Recoverable error          → Failure
Visual screen              → Screen
Reusable component         → Widget
Visual style               → Design System
```

---

# 17. Final Criterion

An implementation is correct if:

- it is easy to understand;
- it respects the UI → Domain → Data flow;
- it can be tested without external services;
- the API can change without breaking the UI;
- the UI can change without breaking Data;
- it maintains business language;
- it does not mix responsibilities;
- it scales without becoming fragile.

An implementation is not acceptable if it works but breaks the architecture.

The goal is not only that it compiles.

The goal is that the system can grow.
