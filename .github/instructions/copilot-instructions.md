# GitHub Copilot Instructions

This repository follows strict AI development governance.

## Required context

Before generating or modifying code, follow:

- `.ai/context/architecture.md`
- `.ai/context/design.md`
- `.ai/context/conventions.md`

## Workflows

For new features:

- `.ai/workflows/create-feature.workflow.md`

For bug fixes:

- `.ai/workflows/fix-bug.workflow.md`

## Architecture rules

- Clean Architecture is mandatory.
- Mandatory flow: UI → Domain → Data.
- UI must never import Data.
- Domain must never import Data or UI.
- DTOs must never leave Data.
- Cubits/Blocs must call UseCases only.
- RepositoryImpl must never be used in UI.
- GetIt must not be used inside UI, Bloc or Cubit.
- Bloc/Cubit must use registerFactory.
- UseCases must return Either<Failure, T>.

## Design rules

- Use the app Design System.
- Use DSResponsive for dimensions.
- Do not hardcode colors, spacing or typography when tokens exist.
- Every screen must handle loading, empty, error and success states.

## Validation

Run:

```bash
dart run tools/architecture_check.dart
```
Code that works but violates architecture is wrong.
