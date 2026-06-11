# AI AGENTS PROJECT INSTRUCTIONS

## Source of truth

All AI tools, coding agents and LLMs working on this repository MUST follow the rules defined in:

- `.ai/context/architecture.md`
- `.ai/context/design.md`
- `.ai/context/conventions.md`

## Available agents

- `.ai/agents/architect.agent.md`
- `.ai/agents/feature-builder.agent.md`
- `.ai/agents/reviewer.agent.md`

## Available workflows

- `.ai/workflows/create-feature.workflow.md`
- `.ai/workflows/fix-bug.workflow.md`

## Spec-Driven Development (MANDATORY)

For Standard and Complex features, a `specs/<app_name>/<feature_name>/spec.md` MUST exist and be approved BEFORE design or implementation begins. If it does not exist, STOP and request it (use `specs/templates/spec.template.md`) — do not implement.

Order: `spec.md` → `plan.md` → `tasks.md` → implementation → validation.

For Quick features, `spec.md` + `tasks.md` are enough, per the workflow's feature levels table.

## Step-by-step approval (MANDATORY)

When executing `.ai/workflows/create-feature.workflow.md`, STOP and wait for explicit approval at these checkpoints:

1. After STEP 1 — architect generates `plan.md`.
2. After STEP 2 — `tasks.md` is created.
3. After STEP 6 — reviewer's assessment is produced.

STEPS 3-5 (implementation, architecture check, debt metrics) run together without pausing — fix any failures per their own rules before reaching STEP 6. STEP 7 (`quickstart.md`) only runs after STEP 6 is approved.

## Mandatory rules

Before modifying code:

1. Read the context files.
2. Follow the appropriate workflow.
3. Respect Clean Architecture.
4. Never allow UI → Data access.
5. Never leak DTOs outside Data.
6. Never bypass UseCases.
7. Never use GetIt inside UI, Bloc or Cubit.
8. Never register Bloc/Cubit as singleton.

## Validation

Before finishing any implementation, run:

```bash
dart run tools/architecture_check.dart
dart run tools/technical_debt_metrics.dart --path lib
```

If the architecture check fails, the task is NOT complete.

## Final rule

If code works but violates architecture, it is wrong.