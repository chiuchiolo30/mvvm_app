# CODE CONVENTIONS CONTRACT (STRICT)

## IMPORTANT

This document defines STRICT coding conventions.

These rules MUST be followed across the entire project.

If code is inconsistent → it is WRONG.

---

# 1. GENERAL PRINCIPLES

Code must be:

* consistent
* explicit
* readable
* predictable
* maintainable

Avoid:

* magic behavior
* implicit logic
* unclear naming

---

# 2. FILE STRUCTURE

## FEATURE-BASED

All code MUST be organized by feature:

lib/
features/
feature_name/
domain/
data/
ui/
di/

---

## FORBIDDEN

* mixing features
* shared logic inside UI folders
* random folders outside structure

---

# 3. NAMING RULES

## FILES

snake_case ONLY

Examples:

get_published_menus_usecase.dart
menu_repository_impl.dart
menu_selection_cubit.dart

---

## CLASSES

PascalCase ONLY

Examples:

GetPublishedMenusUseCase
MenuRepositoryImpl
MenuSelectionCubit

---

## VARIABLES / METHODS

camelCase ONLY

Examples:

getPublishedMenus
selectedCombination
isPrimaryBranch

---

# 4. USECASE CONVENTIONS

## RULES

* MUST represent a business action
* MUST end with `UseCase`
* MUST return `Either<Failure, T>`
* MUST NOT call datasources
* MUST NOT contain UI logic

---

## FILE NAMING

get_published_menus_usecase.dart

---

## FORBIDDEN

Generic naming:

ProcessUseCase ❌
HandleDataUseCase ❌

---

# 5. CUBIT / BLOC CONVENTIONS

## CUBIT PREFERRED

Use Cubit unless complexity requires Bloc.

---

## RULES

* Cubit MUST call UseCases only
* Cubit MUST NOT access Data layer
* Cubit MUST NOT use DTOs
* Cubit MUST NOT contain business logic

---

## STATE RULES

State MUST:

* be immutable
* use Equatable
* have explicit fields
* represent UI clearly

---

## STATUS

Use enum for status:

initial
loading
success
empty
failure

---

## FORBIDDEN

* using String for status ❌
* multiple booleans for state ❌

---

# 6. STATE MANAGEMENT STYLE

## RULE

Prefer explicit transitions over generic copyWith abuse.

---

## ALLOWED

state.loading()
state.success(data)
state.failure(message)

---

## AVOID

copyWith(...) as the only state transition mechanism.

---

# 7. REPOSITORY CONVENTIONS

## DOMAIN

* Repository MUST be abstract
* MUST NOT expose DTOs
* MUST speak business language

---

## DATA

* RepositoryImpl MUST implement domain repository
* MUST convert DTO → Entity
* MUST handle errors → Failure

---

# 8. DTO CONVENTIONS

## RULES

* DTOs MUST stay inside Data
* MUST NOT reach UI
* MUST be mapped to Entities

---

## NAMING

MenuDto
UserDto

---

# 9. MAPPER CONVENTIONS

## RULES

* MUST convert DTO → Entity
* MUST live in Data layer
* MUST NOT contain UI logic

---

# 10. DEPENDENCY INJECTION

## RULES

* Use GetIt
* Register in correct order
* Keep configuration centralized

---

## FORBIDDEN

* GetIt inside UI ❌
* GetIt inside Domain ❌

---

# 11. FUNCTION DESIGN

## RULES

* Functions MUST do ONE thing
* Keep functions small
* Avoid deep nesting

---

## FORBIDDEN

* large functions ❌
* unclear responsibilities ❌

---

# 12. COMMENTS

## RULES

* write comments only when necessary
* code must be self-explanatory

---

## FORBIDDEN

* redundant comments
* commented-out code

---

# 13. ERROR HANDLING

## RULES

* Use Failure pattern
* DO NOT throw raw exceptions to UI
* Map errors in Data layer

---

# 14. IMPORT RULES

## STRICT

* UI MUST NOT import Data
* Domain MUST NOT import Data
* Data MUST NOT import UI

---

# 15. TESTING CONVENTIONS

## PRIORITY

1. UseCases
2. Repositories
3. Cubits
4. Mappers

---

## RULES

* test behavior, not implementation
* use mocks/fakes
* avoid external dependencies

---

# 16. COMMIT CONVENTIONS

## FORMAT

type(scope): description

---

## TYPES

feat
fix
refactor
test
chore

---

## RULES

* lowercase description
* no trailing dot
* clear intent

---

# 17. CONSISTENCY RULE

The project MUST look like:

* written by one developer
* not multiple styles mixed

---

# FINAL RULE

If code works but breaks conventions:

→ IT IS NOT ACCEPTABLE

Consistency is part of quality.
