# Plan Técnico: [Feature Name]

> Generado/validado por: architect.agent.md
> Basado en: spec.md
> Contexto leído: architecture.md, conventions.md, design.md

---

## Resumen de arquitectura

<!-- Descripción de alto nivel de la solución técnica. -->

---

## Capas involucradas

```
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
```

---

## Domain Design

### Entidades

<!-- Listar entidades y sus campos clave. -->

### Repository (abstracto)

```dart
abstract class [Name]Repository {
  // métodos con firma completa
}
```

### UseCases

| UseCase | Input | Output |
|---|---|---|
| `[Name]UseCase` | `[Params]` | `Either<[Failure], [Entity]>` |

### Failures

```dart
sealed class [Name]Failure ...
```

---

## Data Design

### DTOs

<!-- Campos y fuente de datos (Supabase tabla, endpoint, archivo local). -->

### DataSources

| DataSource | Tipo | Método |
|---|---|---|
| `[Name]DataSource` | remote / local | `[método]` |

### RepositoryImpl

<!-- Transformaciones principales: excepción → Failure, DTO → Entity. -->

---

## UI Design

### Screen

- Nombre: `[Name]Screen`
- Cubit: `[Name]Cubit`

### Estados

```dart
enum [Name]Status { initial, loading, success, empty, failure }
```

### Flujo

```
[Name]Screen
  → [Name]Cubit
    → [Name]UseCase
      → [Name]Repository
        → [Name]DataSource
```

---

## Integración con otras features

<!-- Dependencias o comunicación con otras features. -->

- Depende de: ...
- Afecta a: ...

---

## Decisiones técnicas

<!-- Por qué se eligió cada approach. Una línea por decisión. -->

- Usar Cubit (no Bloc) porque el flujo es lineal sin múltiples eventos concurrentes.
- ...

---

## Riesgos

<!-- Solo riesgos reales, no teóricos. -->

- ...

---

## Validación de arquitectura

- [ ] UI no importa Data.
- [ ] Domain no depende de infraestructura.
- [ ] DTOs no salen de Data.
- [ ] UseCases usan repository abstracto.
- [ ] Either con L concreto como subtipo de Failure.
