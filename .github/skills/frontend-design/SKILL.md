---
name: frontend-design
description: Guide for building polished, consistent Flutter UI using the project's design system (DS tokens, molecules, templates). Use this skill when the user asks to create screens, pages, widgets, layouts, or style/beautify any Flutter UI. Ensures proper use of DSColors, DSResponsive, DSSpacings, DSBreakpoints, and theming conventions.
---

This skill guides creation of polished, consistent Flutter UI that properly leverages the project's `design_system` package. Every widget must feel intentional, responsive, and aligned with the existing visual language.

## Design System Overview

The `design_system` package follows Atomic Design and lives in `packages/design_system/`. All classes use the `DS` prefix.

### Tokens (`lib/tokens/`)
Pure value classes with private constructors (`._()`) — never instantiated:

- **`DSColors`** — Material 3 semantic palette: `primary (#03466E)`, `onPrimary`, `surface`, `onSurface`, `error`, `success`, etc.
- **`DSSpacings`** — Spacing values as diagonal-percentage units (used with `DSResponsive.dp()`)
- **`DSSizes`** — Component heights (buttons, inputs, logos) as diagonal-percentage units
- **`DSBorderRadio`** — Border radius values as diagonal-percentage units
- **`DSDurations`** — Animation durations (e.g., `inputToggle: 250ms`)
- **`DSBreakpoints`** — `mobile: 0`, `tablet: 600`, `desktop: 1024`, `xl: 1440`

### Responsive System (`lib/utils/responsive.dart`)
`DSResponsive.of(context)` provides diagonal-percentage sizing:

- `r.dp(percent)` — diagonal-based sizing (primary method for responsive values)
- `r.wp(percent)` / `r.hp(percent)` — width/height percentage
- `r.isMobile` / `r.isTablet` / `r.isDesktop` — breakpoint booleans

### Molecules (`lib/molecules/`)
Reusable widgets: `DSButton`, `DSInputText`, `DSLogo`

### Templates (`lib/templates/`)
`DSResponsiveScreen(mobile:, tablet:, desktop:)` — layout switcher by breakpoint

## Rules

### Always Do
- Pull colors from `Theme.of(context).colorScheme`, **never** directly from `DSColors` in widgets
- Use `DSResponsive.of(context).dp()` for sizing, not hardcoded pixel values
- Use token classes (`DSSpacings`, `DSSizes`, `DSBorderRadio`) for all magic numbers
- Use `DSResponsiveScreen` for layouts that differ across breakpoints
- Use `DSDurations` for animation timings
- Add `const` constructors wherever possible
- Use `DSBreakpoints` values — never hardcode breakpoint thresholds
- Prefer existing DS molecules before creating new widgets
- Export new public widgets through the barrel file (`design_system.dart`)

### Never Do
- Hardcode colors — always go through `ThemeData` / `ColorScheme`
- Hardcode pixel sizes — use `r.dp()`, `r.wp()`, `r.hp()`
- Create one-off styling that belongs in a token class
- Import `dart:ui` for colors in feature code (that's a token concern)
- Skip responsive considerations — every screen must work on mobile, tablet, and desktop
- Use `MediaQuery.of(context).size` directly — use `DSResponsive.of(context)` instead

## Building a New Screen

1. **Structure**: Separate page widget (in `pages/`) from smaller widgets (in `widgets/`)
2. **Responsive**: Use `DSResponsiveScreen` if layouts differ, or `DSResponsive` booleans for minor adjustments
3. **Sizing**: Get `final r = DSResponsive.of(context);` once, use `r.dp()` throughout
4. **Theming**: Get `final t = Theme.of(context);` once, use `t.colorScheme` and `t.textTheme`
5. **Spacing**: Use `SizedBox(height: r.dp(DSSpacings.xxx))` or `EdgeInsets` with `r.dp()`
6. **Animations**: Use `DSDurations` constants, prefer implicit animations (`AnimatedContainer`, `AnimatedOpacity`) for simple transitions

## Building a New DS Component

When creating a new reusable widget for the design system:

1. Determine its atomic level: **token** (value), **molecule** (simple widget), or **template** (layout)
2. Place it in the correct directory
3. Use `DS` prefix for the class name
4. Accept `Key? key` via `super.key`
5. Pull theme from context, sizes from tokens
6. Export it in `design_system.dart`