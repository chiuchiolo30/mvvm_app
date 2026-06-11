# FIX BUG WORKFLOW (STRICT)

## PURPOSE

Fix a bug without introducing regressions or breaking architecture.

This workflow is for:

* runtime bugs
* UI bugs
* state management bugs
* data flow bugs
* navigation bugs
* integration bugs
* architecture-related bugs

---

## REQUIRED CONTEXT

Before starting, you MUST read:

* `.ai/context/architecture.md`

* `.ai/context/design.md`

* `.ai/context/conventions.md`

* `.ai/agents/reviewer.agent.md`

---

## GLOBAL RULE

DO NOT fix before understanding the bug.

No blind changes.

---

# WORKFLOW

## STEP 1 — BUG UNDERSTANDING

Analyze:

* expected behavior
* actual behavior
* affected feature
* affected layer
* reproduction steps
* logs / stack traces if available

---

### OUTPUT REQUIRED

#### 1. Bug Summary

#### 2. Expected Behavior

#### 3. Actual Behavior

#### 4. Suspected Area

* UI
* Cubit/Bloc
* Domain
* Data
* DI
* Routing
* Design System

#### 5. Initial Hypothesis

---

## STEP 2 — IMPACT ANALYSIS

Before changing code, identify:

* files likely involved
* possible architectural risks
* possible regression points
* tests that should be added or updated

---

### OUTPUT REQUIRED

#### 1. Files to Inspect

#### 2. Risk Areas

#### 3. Regression Risk

#### 4. Test Strategy

---

## STEP 3 — FIX PLAN

Create a minimal correction plan.

The fix MUST:

* solve root cause
* avoid unnecessary refactor
* respect architecture
* avoid touching unrelated files

---

### OUTPUT REQUIRED

#### 1. Root Cause

#### 2. Fix Strategy

#### 3. Files to Modify

#### 4. Files NOT to Modify

---

## STOP RULE

After STEP 3:

STOP and wait for approval unless the user explicitly asked to apply the fix directly.

---

## STEP 4 — IMPLEMENT FIX

Apply the smallest valid fix.

Rules:

* do not bypass architecture
* do not move business logic to UI
* do not use DTOs outside Data
* do not call Data directly from UI
* do not introduce global static access
* do not create temporary hacks

---

## STEP 5 — TEST / VALIDATE

Validate with the most relevant checks:

* unit tests
* widget tests
* bloc/cubit tests
* manual reasoning if tests do not exist
* architecture check

Run when available:

dart run tools/architecture_check.dart

---

## STEP 6 — REVIEW

Act as:

.ai/agents/reviewer.agent.md

Review the fix.

---

### OUTPUT REQUIRED

#### 1. Fix Summary

#### 2. Root Cause Confirmed

#### 3. Files Changed

#### 4. Tests / Validation Performed

#### 5. Regression Risks

#### 6. Final Decision

* FIX ACCEPTED
* FIX ACCEPTED WITH WARNINGS
* FIX REJECTED

---

## DEFINITION OF DONE

The bug is fixed ONLY if:

* root cause is identified
* fix is minimal
* architecture is respected
* relevant states still work
* no unrelated behavior changed
* validation passes

---

## STRICT PROHIBITIONS

* random refactors
* speculative rewrites
* changing public contracts without need
* hiding errors instead of fixing them
* suppressing exceptions silently
* adding TODOs instead of solving
* bypassing Clean Architecture
* modifying UI to hide Data problems

---

## FINAL RULE

If the bug disappears but the architecture is damaged:

→ THE FIX IS INVALID
