# DESIGN SYSTEM CONTRACT (STRICT)

## IMPORTANT

This document defines STRICT UI/UX rules.

These rules are NOT optional.
They MUST be followed in every screen, widget and component.

If UI looks like a demo → it is WRONG.

---

# 1. DESIGN GOAL

All UI must feel:

* enterprise-grade
* production-ready
* clean
* modern
* consistent
* mobile-first

---

# 2. DESIGN SYSTEM USAGE (MANDATORY)

## MUST USE

* App Theme
* Design System tokens (colors, spacing, typography)
* Shared components
* DSResponsive (for dimensions)

---

## FORBIDDEN

* hardcoded colors
* hardcoded font sizes
* hardcoded spacing
* inline styling if DS exists
* duplicating existing components

---

## RULE

If a token or component exists → YOU MUST USE IT.

---

# 3. RESPONSIVE DESIGN

## REQUIRED

All dimensions MUST use:

* DSResponsive
* or Design System spacing tokens

---

## FORBIDDEN

```
width: 200 ❌
height: 50 ❌
padding: EdgeInsets.all(16) ❌ (if DS exists)
```

---

## CORRECT

```
DSResponsive.dp(16)
DSSpacing.md
```

---

# 4. UI STATES (MANDATORY)

Every screen MUST implement ALL states:

* initial
* loading
* success
* empty
* error

---

## LOADING

* Must reflect real process
* Avoid generic spinners
* Prefer skeletons or structured loaders

---

## EMPTY

* Must guide the user
* Include message + action (if possible)

---

## ERROR

* Must be human-readable
* Must allow retry
* Never expose technical messages

---

## SUCCESS

* Must be clear and immediate
* Should confirm action result

---

# 5. COMPONENT DESIGN

## RULES

* Components MUST be reusable
* Widgets MUST be small and composable
* Avoid large monolithic widgets

---

## STRUCTURE

Screen
→ Sections
→ Components
→ Atoms

---

## FORBIDDEN

* logic inside UI widgets
* massive build() methods
* repeated UI code

---

# 6. VISUAL HIERARCHY

UI must have clear hierarchy:

* Titles → prominent
* Sections → grouped
* Actions → visible
* Secondary info → subtle

---

## MUST

* use spacing to separate content
* use typography scale
* avoid visual noise

---

# 7. INTERACTIONS

## BUTTONS

Must have:

* enabled state
* disabled state
* loading state

---

## FEEDBACK

User actions MUST provide feedback:

* loading indicator
* success confirmation
* error message

---

# 8. FORMS

## REQUIRED

* validation messages
* clear labels
* input states (error, focus)

---

## FORBIDDEN

* silent failures
* unclear inputs
* missing validation

---

# 9. LISTS & CARDS

## RULES

* must be visually consistent
* must use shared components
* must have spacing between items

---

## EMPTY LIST

Must show:

* explanation
* optional action

---

# 10. NAVIGATION UX

* transitions must feel natural
* avoid abrupt jumps
* maintain context

---

# 11. TEXT & COPY

## RULES

* user-facing text MUST be clear
* avoid technical jargon
* messages must be actionable

---

## FORBIDDEN

* raw error messages
* backend error strings
* debug text in UI

---

# 12. PERFORMANCE UX

## REQUIRED

* avoid blocking UI
* use loading states correctly
* avoid unnecessary rebuilds

---

# 13. CONSISTENCY RULE

All screens MUST:

* look like part of the same product
* reuse same spacing system
* reuse same typography
* reuse same components

---

# 14. DESIGN VALIDATION CHECKLIST

Before completing a screen:

[ ] Uses Design System tokens
[ ] Uses DSResponsive for dimensions
[ ] No hardcoded styles
[ ] All UI states implemented
[ ] Components are reusable
[ ] No logic inside widgets
[ ] Proper spacing and hierarchy
[ ] Error messages are user-friendly
[ ] Buttons have all states
[ ] UI looks production-ready

---

# FINAL RULE

If UI works but looks inconsistent or like a demo:

→ IT IS NOT ACCEPTABLE

Design quality is part of architecture.
