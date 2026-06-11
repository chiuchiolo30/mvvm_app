# Architecture Guidelines

## Propósito

Este documento define las reglas arquitectónicas obligatorias para proyectos Flutter desarrollados bajo Clean Architecture, enfoque feature-first y criterios de mantenibilidad enterprise.

El objetivo es que cualquier desarrollador o agente de IA que trabaje sobre el proyecto respete la misma forma de construir features, separar responsabilidades, nombrar componentes y evitar acoplamientos innecesarios.

---

## Principios base

La arquitectura debe priorizar:

- mantenibilidad;
- testabilidad;
- bajo acoplamiento;
- alta cohesión;
- separación clara de responsabilidades;
- independencia entre UI, dominio y data;
- escalabilidad por features;
- facilidad para trabajar en monorepo;
- consistencia entre módulos;
- código explícito antes que código “mágico”.

La regla principal es:

```txt
UI → Domain → Data
La UI nunca debe acceder directamente a Data.
```

# Estilo arquitectónico principal
### El proyecto utiliza:

```txt
Clean Architecture + Feature-First + DDD liviano
```
La estructura principal debe organizarse por características funcionales.
### Ejemplo:
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
- Cada feature debe ser lo más independiente posible.
- Una feature debe poder evolucionar sin romper otras features.

# Capas permitidas
Cada feature puede tener estas capas:

```
feature/
  domain/
  data/
  ui/
  di/
```
También puede usarse ``presentation/`` en lugar de ``ui/`` o ``infrastructure/`` en lugar de ``data/`` si el proyecto ya lo utiliza, pero debe mantenerse una sola convención dentro del mismo proyecto.

---

## Mapeo a MVVM

Este proyecto se describe en términos de MVVM. Las capas de Clean Architecture definidas arriba se mapean directamente a los roles de MVVM — no hay un patrón adicional que aprender ni implementar:

| Rol MVVM | Equivalente en el proyecto |
|---|---|
| **View** | Screens y Widgets (`ui/screens`, `ui/widgets`) |
| **ViewModel** | Cubit / Bloc (`ui/cubit`, `ui/bloc`) |
| **Model** | Domain (Entities, UseCases, Repositories) + Data (DTOs, DataSources, RepositoryImpl) |

### Reglas

- El Cubit/Bloc **es** el ViewModel: mantiene y expone el estado de presentación, reacciona a acciones de la View, y orquesta el Model a través de UseCases.
- **No** crear una clase `XxxViewModel` separada junto a un Cubit/Bloc — duplicaría la misma responsabilidad y violaría la regla de "no inventar patrones paralelos" (sección 14).
- Todo lo que este documento dice sobre Cubit/Bloc (responsabilidades, diseño de estado, reglas de comunicación, ciclo de vida de DI en la sección 5) aplica al "ViewModel" sin cambios.
- Si se pide "el ViewModel de la feature X", la respuesta es el Cubit/Bloc en `features/x/ui/cubit` (o `bloc`).

---

# 1. Domain Layer
### Responsabilidad

La capa ``domain`` contiene las reglas de negocio y contratos principales de la feature.

Debe ser la capa más estable.

No debe depender de Flutter, Supabase, Firebase, Dio, SQLite, SharedPreferences, APIs externas ni detalles técnicos.

### Puede contener
```
domain/
  entities/
  repositories/
  usecases/
  failures/
  value_objects/
  events/
```
Ejemplo:
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
## Reglas obligatorias de Domain
- Domain no importa Data.
- Domain no importa UI.
- Domain no conoce DTOs.
- Domain no conoce responses de APIs.
- Domain no conoce widgets.
- Domain no conoce Cubits ni Blocs.
- Domain no debe depender de packages de infraestructura.
- Domain define contratos, no implementaciones.
- Los use cases deben expresar acciones de negocio.
- Los repositories en Domain son abstracciones.
## Entities
Las entities representan conceptos del negocio.

Ejemplo:
```
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

### Reglas:
- Las entities deben ser simples.
- Deben representar lenguaje del negocio.
- Deben evitar detalles técnicos.
- No deben usar JSON annotations.
- No deben depender de DTOs.
- Pueden usar ``Equatable``.
- No usar ``freezed`` por defecto en entities, salvo decisión explícita del proyecto.

## Repositories abstractos

Los repositories abstractos viven en Domain.

Ejemplo:

```
abstract class MenuRepository {
  Future<Either<MenuFailure, List<MenuCombination>>> getPublishedMenus({
    required DateTime date,
  });

  Future<Either<MenuFailure, Unit>> selectCombination({
    required String combinationId,
  });
}
```
### Reglas:
- El contrato habla en lenguaje de negocio.
- Retorna entities, value objects o tipos de dominio.
- Nunca retorna DTOs.
- Nunca retorna responses crudas.
- Nunca expone Supabase, Dio, Firebase, SQLite ni detalles externos.

## UseCases
Los use cases representan acciones del negocio, pueden extender de la interface base.

Ejemplo:
```
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

### Reglas:

- Un use case debe tener una responsabilidad clara.
- Debe depender de repositories abstractos.
- Debe retornar Either<Failure, T> cuando exista posibilidad de error.
- No debe acceder directamente a datasources.
- No debe contener lógica de UI.
- No debe manejar navegación.
- No debe mostrar mensajes.
- No debe importar Flutter widgets.

### Naming de UseCases

Usar nombres semánticos y orientados a acción.

#### Buenos ejemplos:
```
SignInUseCase
GetCurrentUserProfileUseCase
GetPublishedMenusUseCase
SelectMenuCombinationUseCase
ValidateTokenUseCase
RefreshTokenUseCase
GetEnabledBranchesUseCase
```

#### Malos ejemplos:
```
MenuUseCase
DataUseCase
CallApiUseCase
ProcessUseCase
HandleUseCase
```
# 2. Data Layer
### Responsabilidad
La capa ``data`` contiene implementaciones concretas, integración con APIs, almacenamiento local, DTOs, mappers y datasources.

Data conoce detalles técnicos.

Domain no debe conocer Data.

### Puede contener
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

Ejemplo:
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
### Reglas obligatorias de Data
- Data puede importar Domain.
- Data implementa repositories definidos en Domain.
- Data contiene DTOs y mappers.
- Data puede usar Supabase, Dio, Firebase, SQLite, SharedPreferences, etc.
- Data no debe importar UI.
- Data no debe depender de Cubits o Blocs.
- Data no debe emitir estados visuales.
- Data no debe manejar navegación.
- Data no debe mostrar SnackBars, dialogs ni loaders.

### RepositoryImpl
Ejemplo:

```
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
### Reglas:
- RepositoryImpl traduce errores técnicos a Failures de dominio.
- RepositoryImpl convierte DTOs a Entities.
- RepositoryImpl no debe devolver DTOs.
- RepositoryImpl no debe exponer excepciones crudas.
- RepositoryImpl no debe tener lógica de UI.

### Datasources
Los datasources son responsables de hablar con fuentes externas.

Ejemplo:
```
abstract class MenuRemoteDataSource {
  Future<List<MenuCombinationDto>> getPublishedMenus({
    required DateTime date,
  });
}
```
Implementación:
```
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

### Reglas:
- Datasource puede lanzar excepciones técnicas.
- Datasource no debe devolver entities.
- Datasource devuelve DTOs o modelos técnicos.
- Datasource no decide reglas de negocio.
- Datasource no maneja navegación.
- Datasource no muestra errores visuales.

### DTOs

Los DTOs representan la forma de los datos externos.

Ejemplo:

```
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

### Reglas:
- DTOs pueden usar freezed, json_serializable o modelos manuales.
- DTOs viven en Data.
- DTOs no deben llegar a UI.
- DTOs no deben ser usados por UseCases.
- DTOs deben mapearse a entities.

### Mappers
Los mappers transforman DTOs en entities y viceversa cuando sea necesario.

Ejemplo:
```
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

### Reglas:

- El mapper debe estar cerca de Data.
- El mapper puede importar Domain.
- El mapper no debe importar UI.
- El mapper debe aislar inconsistencias técnicas de la API.

# 3. UI / Presentation Layer
### Responsabilidad
La capa ``ui`` o ``presentation`` contiene pantallas, widgets, Cubits, Blocs, states y events.

Su responsabilidad es presentar información y reaccionar a interacciones del usuario.

No contiene reglas de negocio profundas.

### Puede contener
```
ui/
  screens/
  widgets/
  cubit/
  bloc/
  state/
```

Ejemplo:
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

### Reglas obligatorias de UI
- UI no puede importar Data.
- UI no puede usar Datasources.
- UI no puede usar RepositoryImpl.
- UI no puede usar DTOs.
- UI no puede llamar APIs directamente.
- UI debe comunicarse con Cubit/Bloc.
- Cubit/Bloc llama UseCases.
- Widgets no deben contener lógica de negocio.
- Widgets deben ser pequeños y componibles.
- Las pantallas deben delegar componentes visuales a widgets.
- La UI debe contemplar estados loading, empty, error y success.

## Flujo correcto
```
Screen
  → Cubit/Bloc
    → UseCase
      → Repository abstracto
        → RepositoryImpl
          → DataSource
            → API / DB / Local Storage
```
## Flujo prohibido
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

# 4. Bloc / Cubit
### Preferencia
Usar ``Cubit`` para flujos simples y medianos.

Usar ``Bloc`` cuando:

- hay muchos eventos explícitos;
- la feature tiene varias entradas de eventos;
- el flujo necesita auditar acciones;
- hay estados complejos derivados de múltiples eventos.

### Responsabilidad del Cubit
El Cubit coordina la UI con los casos de uso.

Puede:

- llamar use cases;
- manejar estados;
- transformar resultados de dominio en estado visual;
- manejar errores de dominio para que la UI los presente;
- preparar datos para la pantalla.

No debe:

- llamar datasources;
- llamar APIs directamente;
- usar DTOs;
- tener lógica de infraestructura;
- manejar detalles visuales finos;
- construir widgets.

### State
Los states deben ser explícitos.

Preferencia:

```
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

Reglas:

- El estado debe ser inmutable.
- Usar Equatable.
- Evitar estados ambiguos.
- Preferir transiciones explícitas.
- Evitar copyWith genérico como única forma de expresar cambios importantes.
- Usar factories o métodos semánticos cuando mejoren la claridad.

### Status
Usar enums claros.

Ejemplo:
```
enum MenuSelectionStatus {
  initial,
  loading,
  success,
  empty,
  failure,
}
```

Reglas:

- No usar strings para estados.
- No mezclar loading con success.
- No representar errores con booleanos sueltos.
- El estado debe permitir pintar la UI sin lógica compleja en el widget.

### Cubit ejemplo
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

## 4.1 Comunicación entre Blocs / Cubits

Los Blocs y Cubits no deben conocerse entre sí directamente.

### Permitido

- `BlocListener` en la UI que reacciona al estado de un Bloc y despacha un evento a otro.
- Un UseCase compartido llamado de forma independiente por dos Blocs distintos.
- El `EventBus` del package `core_domain` para emitir eventos de dominio que múltiples Blocs pueden escuchar.

### Prohibido

- Recibir otro Bloc como parámetro del constructor de un Bloc.
- Llamar `sl.get<OtroBloc>()` dentro de un event handler.
- Agregar eventos a otro Bloc directamente (`otroBloc.add(...)`) desde dentro de un Bloc.
- Mutar el estado de un Bloc desde otro Bloc.

Ejemplo correcto:
```dart
// En la UI, BlocListener coordina dos Blocs sin acoplamiento entre ellos
BlocListener<ScannerBloc, ScannerState>(
  listener: (context, state) {
    if (state is ScannerSuccess) {
      context.read<ProductBloc>().add(LoadProduct(state.barcode));
    }
  },
  child: ...,
)
```

Ejemplo prohibido:
```dart
// ❌ Bloc inyectando otro Bloc en su constructor
class ProductDimensionsBloc extends Bloc<...> {
  final ProductListBloc productListBloc; // prohibido

  void _onSave(SaveEvent event, Emitter emit) {
    productListBloc.add(ModifyProductEvent(...)); // prohibido
  }
}
```

---

# 5. Dependency Injection
### Herramienta recomendada

Usar ``get_it``.

La inyección debe respetar este orden:
```txt
clients
  → datasources
    → repositories
      → usecases
        → cubits/blocs
```
Ejemplo:
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

Reglas:

- No instanciar use cases manualmente dentro de widgets.
- No instanciar repositories manualmente dentro de Cubits.
- No registrar implementaciones antes que sus dependencias.
- No usar service locator directamente en Domain.
- Evitar GetIt.I() dentro de lógica de negocio.
- La composición de dependencias debe estar centralizada.

## Ciclo de vida de registro en GetIt

El tipo de registro determina el ciclo de vida de la instancia. Usarlo mal genera bugs de estado silenciosos.

```
Blocs y Cubits           → registerFactory        (nuevo estado en cada uso)
UseCases                 → registerFactory        (stateless, barato de crear)
RepositoryImpl           → registerLazySingleton  (stateless, 1 instancia suficiente)
DataSources              → registerLazySingleton  (stateless)
Clientes HTTP/Supabase   → registerLazySingleton  (1 conexión global)
Servicios stateless      → registerLazySingleton
```

### Reglas de ciclo de vida

- `registerLazySingleton(() => XxxBloc(...))` **está prohibido**. Un Bloc singleton persiste su estado entre navegaciones y entre sesiones de usuario.
- `registerSingleton` para Blocs o Cubits **está prohibido** por la misma razón.
- Los Blocs y Cubits deben crearse con `registerFactory` para garantizar estado inicial limpio cada vez que la pantalla los instancia.
- Usar `BlocProvider` en el árbol de widgets, no `sl.get<XxxBloc>()` dentro de `initState` ni dentro de `build()`.

Ejemplo correcto:
```dart
// DI
sl.registerFactory(
  () => MenuSelectionCubit(
    getPublishedMenusUseCase: sl(),
    selectMenuCombinationUseCase: sl(),
  ),
);

// Router o pantalla padre
BlocProvider(
  create: (_) => sl<MenuSelectionCubit>(),
  child: MenuSelectionScreen(),
)
```

Ejemplo prohibido:
```dart
// ❌ Bloc como singleton — el estado no se reinicia
sl.registerLazySingleton(() => MenuSelectionCubit(...));

// ❌ GetIt dentro de initState o build
@override
void initState() {
  super.initState();
  _cubit = sl.get<MenuSelectionCubit>(); // prohibido
}
```

# 6. Routing
### Responsabilidad

El routing debe manejar navegación, no lógica de negocio.

Preferencia: 
```txt
GoRouter
```
Puede usarse ``go_router_builder`` si el proyecto lo requiere.

### Reglas
- Las rutas deben ser declarativas.
- No pasar objetos complejos innecesariamente por rutas.
- Evitar depender de history.state para información crítica.
- Para datos de sesión, preferir storage controlado o estado global.
- La navegación basada en rol debe decidirse con información del perfil autenticado.
- Los guards deben ser simples y predecibles.

Ejemplo de decisión:
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

# 7. Design System y UI
### Regla principal

Toda UI debe respetar el Design System del proyecto.

La UI no debe sentirse como demo.

Debe sentirse:
```
enterprise
mobile-first
moderna
limpia
consistente
robusta
```

### Reglas obligatorias
- Usar theme de la aplicación.
- Usar tokens del Design System.
- Usar DSResponsive para dimensiones cuando exista.
- No hardcodear colores.
- No hardcodear tamaños si hay tokens disponibles.
- No crear estilos aislados si ya existe un componente o token.
- Diseñar todos los estados:
    - initial;
    - loading;
    - empty;
    - error;
    - success.
- Loading debe reflejar el proceso real cuando hay pasos.
- Empty states deben orientar al usuario.
- Error states deben permitir recuperación.
- Las cards deben tener jerarquía visual clara.
- Los formularios deben tener validación clara.
- Los botones deben tener estados disabled/loading.
- Los widgets deben ser reutilizables.

### Prohibido en UI
- Poner lógica de negocio dentro del build.
- Hacer llamadas HTTP desde un widget.
- Consultar Supabase/Firebase/Dio directamente desde UI.
- Crear colores sueltos sin token.
- Duplicar componentes existentes del Design System.
- Usar textos técnicos para errores de usuario.
- Hacer pantallas sin empty/error/loading state.

# 8. Manejo de errores
### Patrón recomendado

Usar Failure en Domain.

Ejemplo:
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
  String get message => 'No pudimos cargar los menús. Revisá tu conexión.';
}

class MenuUnexpectedFailure extends MenuFailure {
  const MenuUnexpectedFailure({
    this.error,
    this.stackTrace,
  });

  final Object? error;
  final StackTrace? stackTrace;

  @override
  String get message => 'Ocurrió un error inesperado.';
}

```

### Reglas:

- Data captura errores técnicos.
- Data transforma errores técnicos en Failures.
- Domain expone Failures.
- Cubit traduce Failures a estados.
- UI muestra mensajes entendibles.
- No mostrar stack traces al usuario.
- No filtrar excepciones técnicas a UI.

## Either tipado — regla obligatoria

Todo `Either` que represente un resultado de negocio **debe tener el tipo izquierdo ligado a `Failure`**.

```dart
// Correcto — el compilador garantiza que L es un Failure concreto
Future<Either<MenuFailure, List<MenuCombination>>> getPublishedMenus();
Future<Either<Failure, User>> login(Credentials creds);

// Prohibido — genéricos libres anulan el contrato
Future<Either<L, R>> call<L, R>();  // L puede ser cualquier tipo
Future<Either<dynamic, dynamic>> call();
```

Reglas:
- `L` en `Either<L, R>` **siempre** debe ser un subtipo de `Failure` del package `core_domain`.
- **Prohibido** `Either<L, R>` con `L` y `R` como parámetros de tipo libres (unbound generics) en UseCases, Repositories y DataSources.
- El Cubit debe poder llamar `.fold((Failure f) ..., (T value) ...)` con seguridad de tipos, sin casteos.

# 9. Testing
### Prioridad de tests

La prioridad debe ser:
```
UseCases
Repositories
Cubits/Blocs
Mappers
Widgets críticos
```

### Tests de UseCases

Validar:

- que llamen al repository correcto;
- que propaguen Right correctamente;
- que propaguen Left correctamente;
- que no dependan de Data.

### Tests de RepositoryImpl

Validar:

- que invoque datasource;
- que convierta DTOs a entities;
- que traduzca errores a Failures;
- que no exponga excepciones crudas.

### Tests de Cubit

Validar:

- estado inicial;
- loading;
- success;
- empty;
- failure;
- secuencia de estados;
- comportamiento ante errores.

### Reglas
- Usar mocks/fakes claros.
- No testear detalles irrelevantes.
- No depender de servicios externos reales.
- Los tests deben documentar comportamiento, no implementación accidental.

# 10. Monorepo
### Compatibilidad

La arquitectura debe poder adaptarse a monorepos con apps y packages.

Ejemplo:
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

### Reglas para monorepo
- Las apps consumen packages.
- Los packages compartidos no deben depender de apps.
- design_system no debe depender de features.
- core_network no debe depender de UI.
- core_domain no debe depender de Data.
- Las features reutilizables pueden vivir como package si tienen sentido.
- No mover una feature a package antes de que exista una necesidad real de reutilización.

### Dependencias permitidas
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
### Dependencias prohibidas
```
design_system → app
core_network → ui
core_domain → data
domain → supabase
domain → dio
ui → datasource
ui → repository_impl
```

# 11. Convenciones de nombres
### Archivos

Usar snake_case.
```
get_published_menus_usecase.dart
menu_repository_impl.dart
menu_remote_datasource.dart
menu_selection_cubit.dart
menu_selection_state.dart
```
### Clases

Usar PascalCase.
```
GetPublishedMenusUseCase
MenuRepositoryImpl
MenuRemoteDataSource
MenuSelectionCubit
MenuSelectionState
```

### Variables y métodos

Usar lowerCamelCase.

```
getPublishedMenus
selectedCombination
isPrimaryBranch
```

### Sufijos esperados

```
UseCase      (PascalCase en clase, _usecase.dart en archivo)
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

### Regla de consistencia en naming de UseCase

- La clase siempre termina en `UseCase` (PascalCase): `GetPublishedMenusUseCase`.
- El archivo siempre termina en `_usecase.dart` (snake_case): `get_published_menus_usecase.dart`.
- **Prohibido** mezclar `Usecase`, `usecase`, `UseCase` en el mismo proyecto.
- Los nombres deben ser semánticos y orientados a acción. Ver ejemplos en sección 1.

# 12. Reglas anti-acoplamiento

## Prohibición de acceso estático global

El acceso estático a configuración, preferencias o variables de entorno dentro de capas internas viola Dependency Inversion y hace el código intestable.

### Prohibido en Domain y Data

```dart
// ❌ Acceso estático en DataSource
final branchId = PreferencesApp.sucursal; // prohibido
final url = dotenv.env['SERVER_URL']!;    // prohibido
final dni = SharedPreferences.getString('dni'); // prohibido
```

### Correcto

Definir una interfaz en Domain o en el package compartido e inyectarla:

```dart
// Domain o core_domain
abstract class IUserSession {
  String get sucursal;
  String get dni;
}

// Data — DataSource recibe la interfaz por constructor
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

### Regla crítica

La UI no accede a Data.

Esto está prohibido:
```dart
import 'package:app/features/menu/data/repositories/menu_repository_impl.dart';
import 'package:app/features/menu/data/datasources/menu_remote_datasource.dart';
import 'package:app/features/menu/data/dtos/menu_combination_dto.dart';
```
Dentro de:
```
ui/
presentation/
screens/
widgets/
cubit/
bloc/
```

### También está prohibido

Domain importando Data:
```dart
import '../../data/...';
```

Data importando UI:
```dart
import '../../ui/...';
```

Packages core importando features:
```dart
import 'package:app/features/...';
```

# 13. Fitness Functions

Las reglas arquitectónicas **se verifican automáticamente** mediante dos mecanismos complementarios:

## 13.1 Script de validación (`tools/architecture_check.dart`)

Ejecutar con:
```bash
dart run tools/architecture_check.dart
```

Retorna exit code 1 si hay violaciones, lo que permite integrarlo en CI. Valida:

### Regla 1 — UI no puede importar Data
```
Ningún archivo bajo */ui/**/*.dart puede importar desde */data/
```

### Regla 2 — Domain no puede importar Data ni UI
```
Ningún archivo bajo */domain/**/*.dart puede importar desde */data/ o */ui/
```

### Regla 3 — Data no puede importar UI
```
Ningún archivo bajo */data/**/*.dart puede importar desde */ui/ o */presentation/
```

### Regla 4 — DTOs no pueden aparecer fuera de Data
```
Clases con sufijo Dto solo pueden existir dentro de */data/
```

### Regla 5 — RepositoryImpl no puede usarse desde UI
```
Clases con sufijo RepositoryImpl no pueden ser importadas por UI
```

### Regla 6 — GetIt prohibido en UI/Bloc
```
Llamadas a sl.get<> o sl() no pueden aparecer en archivos bajo */ui/, */screens/, */widgets/, */cubit/, */bloc/
```

### Regla 7 — Blocs no pueden registrarse como LazySingleton
```
registerLazySingleton con factory que retorna un tipo Bloc o Cubit está prohibido
```

### Regla 8 — Either con genéricos libres prohibido en Domain y Data
```
El patrón Either<L, R> con type params libres no puede aparecer en */domain/ ni */data/
```

### Regla 9 — Archivos UseCase deben respetar la convención de nombres (AST)
```
Archivos llamados *_usecase.dart deben declarar una clase que termine en UseCase
```

### Regla 10 — RepositoryImpl debe implementar un Repository (AST)
```
Clases que terminan en RepositoryImpl deben implementar al menos una interfaz que termine en Repository
```

### Regla 11 — Cubit/Bloc no puede depender de otro Cubit/Bloc en su constructor (AST)
```
Los parámetros de constructor de una clase Cubit/Bloc no pueden ser de tipo Cubit o Bloc
```

### Regla 12 — Datasource no puede retornar tipos Entity (AST)
```
Los métodos de clases que terminan en DataSource no pueden retornar tipos Entity
```

## 13.2 Reglas de lint en tiempo real (`packages/lint_rules`)

El package `lint_rules` usa `custom_lint` para mostrar errores directamente en el IDE y en `dart analyze`.

Activar en `analysis_options.yaml` de cada app:
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

Reglas disponibles:

| Regla | Detecta | Severidad |
|---|---|---|
| `avoid_get_it_in_ui` | `sl.get<>()` en archivos de UI/Bloc/Cubit | error |
| `avoid_bloc_as_lazy_singleton` | `registerLazySingleton` retornando Bloc/Cubit | warning |
| `avoid_untyped_either` | `Either<L, R>` con genéricos libres | error |
| `avoid_direct_bloc_dependency` | Campo de tipo Bloc/Cubit en otro Bloc/Cubit | warning |

---

# 13.3 Métricas de deuda técnica (`tools/technical_debt_metrics.dart`)

Ejecutar con:

```bash
dart run tools/technical_debt_metrics.dart --path lib
```

Siempre sale con código 0 (solo reporta, no bloquea CI). Genera un reporte estructurado por scope.

> **Nota single-package**: este proyecto no tiene estructura de monorepo (`apps/`/`packages/`). Pasar siempre `--path lib` para acotar el reporte al código de la aplicación. Sin `--path`, la herramienta analiza todo el repositorio — incluyendo `tools/` mismo — como scope `monorepo`, lo que produce resultados engañosos (la complejidad de los propios scripts de gobernanza se reporta como deuda del proyecto). `--path lib` resuelve al scope `unknown`, que se evalúa contra los umbrales de la política `monorepo` (ver 13.4).

### Métricas recolectadas

| Métrica | Descripción |
|---|---|
| LOC | Líneas de código (sin blancos ni comentarios) |
| Clases | Cantidad de declaraciones de clases |
| Funciones | Cantidad de métodos/funciones declarados |
| CC | Complejidad Ciclomática (por función) |
| CogC | Complejidad Cognitiva — modelo Sonar/Richards (por función) |
| Nesting | Profundidad máxima de anidamiento (por función) |
| Ca | Acoplamiento aferente — imports entrantes (funcional / técnico separado) |
| Ce | Acoplamiento eferente — imports salientes |
| I | Inestabilidad = Ce / (Ca + Ce) |
| A | Abstracción = clases abstractas / total clases |
| D | Distancia de la secuencia principal = \|A + I − 1\| (interpretada por Policy Engine) |
| Hotspots | Funciones con mayor puntaje combinado de CC + CogC + Nesting |

### Scopes

| Scope | Ejemplo |
|---|---|
| `feature` | Un package de feature individual |
| `app` | Un package de app |
| `package` | Un package compartido |
| `appsGroup` | Todas las apps |
| `packagesGroup` | Todos los packages |
| `monorepo` | Todo el repositorio |

### Umbrales

**CC:** ✅ 0–10 / ⚠️ 11–15 / ❌ 16–24 / 🚨 25+

**CogC:** ✅ 0–10 / ⚠️ 11–20 / ❌ 21–30 / 🚨 31+

**Nesting:** ✅ 0–3 / ⚠️ 4–5 / ❌ 6–7 / 🚨 8+

---

# 13.4 Policy Engine

El Policy Engine aplica umbrales contextuales a las métricas. Archivo de política por defecto: `.ai/architecture-policies.yaml`.

```bash
dart run tools/technical_debt_metrics.dart --path lib --policy .ai/architecture-policies.yaml
```

### Scopes de política

Cada scope (`feature`, `app`, `package`, `monorepo`) puede definir umbrales independientes para:

- `cc.warning`, `cc.error`
- `cogc.warning`, `cogc.error`
- `nesting.warning`, `nesting.error`
- `instability.warning`, `instability.error`
- `abstraction.distance.warning`, `abstraction.distance.error`, `abstraction.distance.mode`

### Modos de enforcement

| Modo | Comportamiento |
|---|---|
| `reportOnly` | Imprime la evaluación de política, nunca falla |
| `failOnError` | Sale con código no-cero si algún umbral de error es superado |
| `failOnRegression` | Sale con código no-cero solo si una métrica regresó vs. baseline |

Por defecto: `reportOnly` para todos los scopes.

### Interpretación de D (distancia)

`D` (distancia de la secuencia principal) **no** se evalúa con umbrales globales fijos. Su interpretación se delega completamente al Policy Engine por scope. Ejemplo: `feature.abstraction.distance.mode = informational` significa que D se muestra pero nunca se marca como error.

---

# 13.5 Baselines evolutivos

Los baselines capturan un snapshot de métricas para comparación a lo largo del tiempo.

```bash
# Exportar un baseline
dart run tools/technical_debt_metrics.dart --path lib --export-baseline

# Comparar contra un baseline
dart run tools/technical_debt_metrics.dart --path lib --compare-baseline
```

### Almacenamiento de baselines

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

### Formato del baseline (v1)

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

### Reporte de delta

La comparación muestra diffs de 12 métricas más cambios en hotspots con indicadores direccionales (▲ regresión / ▼ mejora / = sin cambios).

---

# 13.6 Spec-Driven Development

Spec-Driven Development (SDD) es la práctica de escribir una especificación explícita y revisable antes de comenzar la implementación. No es un ejercicio de documentación — es la fuente principal de contexto para agentes IA y desarrolladores humanos.

## Principio

```
spec → plan → tasks → implementación → validación
```

Nunca implementar contra un requerimiento verbal.  
Siempre implementar contra una spec escrita y aprobada.

## Niveles de feature

| Nivel | Archivos requeridos |
|---|---|
| Quick | `spec.md`, `tasks.md` |
| Standard | `spec.md`, `plan.md`, `tasks.md`, `quickstart.md` |
| Complex | Standard + opcional `research.md`, `data-model.md`, `contracts/` |

## Estructura de archivos

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

## Integración con agentes IA

| Agente | Lee | Produce |
|---|---|---|
| `architect.agent.md` | `spec.md` + archivos de contexto | `plan.md` |
| `feature-builder.agent.md` | `plan.md` + `tasks.md` + archivos de contexto | Implementación |
| `reviewer.agent.md` | `spec.md` + `plan.md` + archivos de contexto | Review con tabla de compliance |

## Integración con gobernanza

- `plan.md` debe referenciar el baseline actual de `.ai/architecture-baselines/`.
- `tasks.md` debe incluir un bloque de validación: `check:arch` + `check:debt` + comparación de baseline.
- `quickstart.md` debe cubrir todos los acceptance criteria de `spec.md` como escenarios de prueba.
- El reviewer debe producir una tabla de spec compliance que mapea cada criterio a un estado de implementación.

---

# 14. Reglas para agentes de IA

Cuando un agente trabaje sobre este proyecto debe:

- leer este archivo antes de modificar código;
- respetar la estructura existente;
- no inventar arquitectura nueva;
- no cambiar nombres de carpetas sin justificación;
- no mover lógica entre capas sin explicar por qué;
- no tocar Data cuando la tarea sea solo UI;
- no tocar UI cuando la tarea sea solo Domain/Data;
- no crear DTOs en UI;
- no crear lógica de negocio en widgets;
- no crear dependencias circulares;
- no hardcodear estilos visuales;
- no reemplazar patrones existentes por preferencias propias;
- no crear código “demo” en pantallas productivas.

# 15. Checklist antes de finalizar una feature

Antes de considerar terminada una feature, validar:
```
[ ] La UI no importa Data.
[ ] Domain no importa Data ni UI.
[ ] Data no importa UI.
[ ] Los UseCases dependen de repositories abstractos.
[ ] RepositoryImpl implementa un repository de Domain.
[ ] DTOs no salen de Data.
[ ] Hay mappers entre DTOs y Entities.
[ ] Cubit/Bloc no llama datasources.
[ ] La UI contempla loading, empty, error y success.
[ ] Los errores técnicos se transforman en Failures.
[ ] Either<L, R> usa L concreto como subtipo de Failure (no genéricos libres).
[ ] La inyección de dependencias respeta el orden correcto.
[ ] Blocs y Cubits registrados con registerFactory, no registerLazySingleton.
[ ] No hay sl.get<>() dentro de Blocs, Cubits, Screens ni Widgets.
[ ] No hay acceso estático a PreferencesApp/dotenv dentro de Domain o Data.
[ ] Blocs no tienen dependencias directas a otros Blocs en su constructor.
[ ] Los nombres siguen las convenciones (sufijo UseCase en PascalCase, archivo _usecase.dart).
[ ] No hay lógica de negocio pesada en widgets.
[ ] No hay estilos hardcodeados si existe Design System.
[ ] Hay tests al menos para use cases, cubits o repositories críticos.
[ ] dart run tools/architecture_check.dart pasa sin errores.
[ ] dart run tools/technical_debt_metrics.dart revisado — sin regresiones inaceptables vs. baseline.
```
# 16. Decisiones por defecto

Cuando haya duda, aplicar estas decisiones:
```
Estado simple → Cubit
Estado complejo/event-driven → Bloc
Datos externos → DataSource
Regla de negocio → UseCase
Contrato de negocio → Repository abstracto
Implementación técnica → RepositoryImpl
Transformación API ↔ Domain → Mapper
Error recuperable → Failure
Pantalla visual → Screen
Componente reusable → Widget
Estilo visual → Design System
```

# 17. Criterio final

Una implementación es correcta si:

- se entiende fácilmente;
- respeta el flujo UI → Domain → Data;
- puede testearse sin servicios externos;
- puede cambiar la API sin romper la UI;
- puede cambiar la UI sin romper Data;
- mantiene el lenguaje del negocio;
- no mezcla responsabilidades;
- escala sin volverse frágil.

Una implementación no es aceptable si funciona, pero rompe la arquitectura.

El objetivo no es solo que compile.

El objetivo es que el sistema pueda crecer.