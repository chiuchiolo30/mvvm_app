# CLAUDE PROJECT MEMORY

This repository uses strict AI development governance.

## Always read first

- `.ai/context/architecture.md`
- `.ai/context/design.md`
- `.ai/context/conventions.md`

## Roles

Use these role definitions when relevant:

- Architect: `.ai/agents/architect.agent.md`
- Feature Builder: `.ai/agents/feature-builder.agent.md`
- Reviewer: `.ai/agents/reviewer.agent.md`

## Workflows

For new features:

- `.ai/workflows/create-feature.workflow.md`

For bug fixing:

- `.ai/workflows/fix-bug.workflow.md`

## Spec-Driven Development (MANDATORY)

For Standard and Complex features:

- A `specs/<app_name>/<feature_name>/spec.md` MUST exist and be approved BEFORE any architecture design or implementation starts.
- If it does not exist, STOP and request it (use `specs/templates/spec.template.md`). Do not implement.
- Follow the order: `spec.md` → `plan.md` → `tasks.md` → implementation → validation, per `.ai/workflows/create-feature.workflow.md`.

For Quick features, `spec.md` + `tasks.md` are enough, per the workflow's feature levels table.

## Step-by-step approval (MANDATORY)

When executing `.ai/workflows/create-feature.workflow.md`, STOP and wait for explicit approval at these checkpoints:

1. After STEP 1 — architect generates `plan.md`.
2. After STEP 2 — `tasks.md` is created.
3. After STEP 6 — reviewer's assessment is produced.

STEPS 3-5 (implementation, architecture check, debt metrics) run together without pausing — fix any failures per their own rules before reaching STEP 6. STEP 7 (`quickstart.md`) only runs after STEP 6 is approved.

## Non-negotiable rules

- UI must never access Data.
- Domain must never depend on Data or UI.
- DTOs must never leave Data.
- Cubits/Blocs must call UseCases only.
- RepositoryImpl must never be used from UI.
- GetIt must not be used inside UI, Bloc or Cubit.
- Bloc/Cubit must be registered with registerFactory.
- UseCases must return Either<Failure, T>.
- Design System and DSResponsive must be respected.

## Validation commands

```bash
dart run tools/architecture_check.dart
dart run tools/technical_debt_metrics.dart --path lib
```
If validation fails, fix it before finishing.