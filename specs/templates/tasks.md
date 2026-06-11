# Tasks: [Feature Name]

> Ejecutar en orden. Cada bloque debe estar completo antes de pasar al siguiente.
> Builder: seguir plan.md y context/architecture.md.

---

## Bloque 1 — Domain

- [ ] Crear entidad `[Name]`
- [ ] Crear `[Name]Failure`
- [ ] Crear `[Name]Repository` (abstracto)
- [ ] Crear `[Name]UseCase`

---

## Bloque 2 — Data

- [ ] Crear `[Name]Dto`
- [ ] Crear `[Name]DataSource` (abstracto + implementación)
- [ ] Crear mapper `[Name]DtoMapper`
- [ ] Crear `[Name]RepositoryImpl`

---

## Bloque 3 — UI

- [ ] Crear `[Name]State` con enum `[Name]Status`
- [ ] Crear `[Name]Cubit`
- [ ] Crear `[Name]Screen` con estados: loading, empty, error, success
- [ ] Crear widgets auxiliares si corresponde

---

## Bloque 4 — DI

- [ ] Registrar datasource (`registerLazySingleton`)
- [ ] Registrar repository (`registerLazySingleton`)
- [ ] Registrar usecase (`registerFactory`)
- [ ] Registrar cubit (`registerFactory`)

---

## Bloque 5 — Validación

- [ ] `dart run tools/architecture_check.dart` pasa sin errores
- [ ] `dart run tools/technical_debt_metrics.dart --path lib` revisado — sin regresiones inesperadas
- [ ] Comparar contra baseline si existe: `dart run tools/technical_debt_metrics.dart --path lib --compare-baseline`
- [ ] Exportar nuevo baseline si la feature es significativa: `dart run tools/technical_debt_metrics.dart --path lib --export-baseline`

---

## Bloque 6 — Review

- [ ] Reviewer revisó implementación contra spec.md y plan.md
- [ ] Decisión: APPROVED / APPROVED WITH CHANGES / REJECTED
