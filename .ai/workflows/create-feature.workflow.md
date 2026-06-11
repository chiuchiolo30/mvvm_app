# CREATE FEATURE WORKFLOW (STRICT)

## PURPOSE

Create a production-ready feature following:

* Clean Architecture
* Design System rules
* Code conventions
* Project standards
* Spec-Driven Development

This workflow MUST be followed step by step.

---

## FEATURE LEVELS

| Level | Required files |
|---|---|
| Quick | `spec.md`, `tasks.md` |
| Standard | `spec.md`, `plan.md`, `tasks.md`, `quickstart.md` |
| Complex | Standard + optional `research.md`, `data-model.md`, `contracts/` |

When in doubt: use Standard.

---

## REQUIRED CONTEXT (MANDATORY)

Before starting, you MUST read:

* `.ai/context/architecture.md`

* `.ai/context/design.md`

* `.ai/context/conventions.md`

* `.ai/agents/architect.agent.md`

* `.ai/agents/feature-builder.agent.md`

* `.ai/agents/reviewer.agent.md`

If a spec exists for the feature, also read:

* `specs/<app_name>/<feature_name>/spec.md`

---

## GLOBAL RULE

NEVER implement code before completing architecture design.

---

# WORKFLOW

## STEP 0 — SPEC (Standard and Complex features)

Create or verify existence of:

```
specs/<app_name>/<feature_name>/spec.md
```

Use template: `specs/templates/spec.template.md`

The spec MUST define:

* functional objective
* user stories
* acceptance criteria
* edge cases
* business rules
* UX restrictions

---

### STOP RULE

After this step:

STOP.

Wait for spec approval before continuing.

---

## STEP 1 — ARCHITECTURE DESIGN

Act as:

.ai/agents/architect.agent.md

---

### TASK

Read `spec.md` (if exists) and design the feature BEFORE implementation.

Generate or validate:

```
specs/<app_name>/<feature_name>/plan.md
```

Use template: `specs/templates/plan.md`

---

### OUTPUT (MANDATORY)

You MUST provide:

#### 1. Feature Summary

* purpose
* user flow

#### 2. Domain Design

* entities
* use cases
* repository (abstract)

#### 3. Data Design

* DTOs
* data sources
* repository implementation
* mappers

#### 4. UI Design

* screen
* cubit / bloc
* states (loading, success, empty, error)

#### 5. Architecture Validation

* confirm no rule is violated
* list risks if any

#### 6. Spec Traceability (when spec.md exists)

* map each acceptance criterion to a design element
* flag unimplemented criteria

---

### STOP RULE

After this step:

STOP.

Wait for approval before continuing.

---

## STEP 2 — TASKS

Create:

```
specs/<app_name>/<feature_name>/tasks.md
```

Use template: `specs/templates/tasks.md`

Tasks MUST be ordered:

1. Domain
2. Data
3. UI
4. DI
5. Validation (arch check + debt + baseline)
6. Review

---

## STEP 3 — IMPLEMENTATION

Act as:

.ai/agents/feature-builder.agent.md

---

### TASK

Implement the feature based ONLY on approved design.

Follow `tasks.md` block by block.

---

### IMPLEMENTATION ORDER (MANDATORY)

1. Domain
2. Data
3. UI
4. Dependency Injection

---

### OUTPUT (MANDATORY)

You MUST return:

#### 1. File Structure

feature/
domain/
data/
ui/
di/

---

#### 2. Domain Code

* entities
* repository
* use cases

---

#### 3. Data Code

* DTOs
* datasource
* repository implementation
* mapper

---

#### 4. UI Code

* cubit / bloc
* state
* screen (base structure)

---

#### 5. Dependency Injection

GetIt configuration

---

## STEP 4 — ARCHITECTURE VALIDATION

Run:

```bash
dart run tools/architecture_check.dart
```

### RULE

If validation fails:

* FIX issues
* DO NOT continue

---

## STEP 5 — DEBT & BASELINE

Run:

```bash
dart run tools/technical_debt_metrics.dart --path lib
```

If a baseline exists, compare:

```bash
dart run tools/technical_debt_metrics.dart --path lib --compare-baseline
```

### RULE

* Review hotspots from baseline.
* If any metric regressed significantly → FIX before proceeding.
* If feature is new or significantly changed → export new baseline:

```bash
dart run tools/technical_debt_metrics.dart --path lib --export-baseline
```

---

## STEP 6 — REVIEW

Act as:

.ai/agents/reviewer.agent.md

---

### TASK

Review the implementation against:

* `spec.md` (acceptance criteria, edge cases, business rules)
* `plan.md` (architecture decisions)
* `.ai/context/architecture.md`
* baseline hotspots

---

### OUTPUT (MANDATORY)

#### 1. Overall Assessment

* score (1–10)
* summary

#### 2. Critical Issues

(must fix)

#### 3. Medium Issues

(should fix)

#### 4. Minor Issues

(optional)

#### 5. Architecture Compliance

#### 6. Design Compliance

#### 7. Spec Compliance

| Acceptance Criterion | Implemented? |
|---|---|
| ... | ✅ / ❌ |

#### 8. Debt & Baseline

#### 9. Final Decision

* APPROVED
* APPROVED WITH CHANGES
* REJECTED

---

## STEP 7 — QUICKSTART (Standard and Complex features)

Create:

```
specs/<app_name>/<feature_name>/quickstart.md
```

Use template: `specs/templates/quickstart.md`

---

## DEFINITION OF DONE

The feature is complete ONLY if:

* spec approved (Standard/Complex)
* architecture design approved
* implementation follows design
* tasks.md completed
* `dart run tools/architecture_check.dart` passes
* debt metrics reviewed — no unacceptable regressions
* reviewer approves
* quickstart.md written (Standard/Complex)
* no UI → Data dependency exists
* all UI states are implemented
* Design System is respected

---

## STRICT PROHIBITIONS

* skipping Step 0 (spec) for Standard/Complex features
* skipping Step 1 (design)
* implementing without approval
* mixing layers
* accessing Data from UI
* leaking DTOs
* ignoring reviewer feedback
* ignoring baseline regressions

---

## FINAL RULE

If the feature works but breaks architecture:

→ IT IS NOT COMPLETE

## PURPOSE

Create a production-ready feature following:

* Clean Architecture
* Design System rules
* Code conventions
* Project standards

This workflow MUST be followed step by step.

---

## REQUIRED CONTEXT (MANDATORY)

Before starting, you MUST read:

* `.ai/context/architecture.md`

* `.ai/context/design.md`

* `.ai/context/conventions.md`

* `.ai/agents/architect.agent.md`

* `.ai/agents/feature-builder.agent.md`

* `.ai/agents/reviewer.agent.md`

---

## GLOBAL RULE

NEVER implement code before completing architecture design.

---

# WORKFLOW

## STEP 1 — ARCHITECTURE DESIGN

Act as:

.ai/agents/architect.agent.md

---

### TASK

Design the feature BEFORE implementation.

---

### OUTPUT (MANDATORY)

You MUST provide:

#### 1. Feature Summary

* purpose
* user flow

#### 2. Domain Design

* entities
* use cases
* repository (abstract)

#### 3. Data Design

* DTOs
* data sources
* repository implementation
* mappers

#### 4. UI Design

* screen
* cubit / bloc
* states (loading, success, empty, error)

#### 5. Architecture Validation

* confirm no rule is violated
* list risks if any

---

### STOP RULE

After this step:

STOP.

Wait for approval before continuing.

---

## STEP 2 — IMPLEMENTATION

Act as:

.ai/agents/feature-builder.agent.md

---

### TASK

Implement the feature based ONLY on approved design.

---

### IMPLEMENTATION ORDER (MANDATORY)

1. Domain
2. Data
3. UI
4. Dependency Injection

---

### OUTPUT (MANDATORY)

You MUST return:

#### 1. File Structure

feature/
domain/
data/
ui/
di/

---

#### 2. Domain Code

* entities
* repository
* use cases

---

#### 3. Data Code

* DTOs
* datasource
* repository implementation
* mapper

---

#### 4. UI Code

* cubit / bloc
* state
* screen (base structure)

---

#### 5. Dependency Injection

GetIt configuration

---

## STEP 3 — REVIEW

Act as:

.ai/agents/reviewer.agent.md

---

### TASK

Review the implementation.

---

### OUTPUT (MANDATORY)

#### 1. Overall Assessment

* score (1–10)
* summary

#### 2. Critical Issues

(must fix)

#### 3. Medium Issues

(should fix)

#### 4. Minor Issues

(optional)

#### 5. Architecture Compliance

#### 6. Design Compliance

#### 7. Final Decision

* APPROVED
* APPROVED WITH CHANGES
* REJECTED

---

## STEP 4 — ARCHITECTURE VALIDATION

Run:

dart run tools/architecture_check.dart

---

### RULE

If validation fails:

* FIX issues
* DO NOT finish workflow

---

## DEFINITION OF DONE

The feature is complete ONLY if:

* architecture design was approved
* implementation follows design
* reviewer approves
* architecture check passes
* no UI → Data dependency exists
* all UI states are implemented
* Design System is respected

---

## STRICT PROHIBITIONS

* skipping Step 1
* implementing without approval
* mixing layers
* accessing Data from UI
* leaking DTOs
* ignoring reviewer feedback

---

## FINAL RULE

If the feature works but breaks architecture:

→ IT IS NOT COMPLETE
