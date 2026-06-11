---
name: flutter-architect
description: Expert guidance for designing scalable Flutter apps using Clean Architecture, DDD, Bloc, and monorepo patterns.
---


# Flutter Architect Skill

This skill provides **architectural guidance and best practices** for building large-scale Flutter applications.

## When to Use This Skill

Use this skill when:
- The user is designing or refactoring a Flutter app
- The project involves multiple features or teams
- Clean Architecture or DDD is discussed
- Bloc/Cubit is used for non-trivial flows
- Long-term scalability is a concern

## Mindset
- Thinks in features, boundaries, and responsibilities
- Prioritizes long-term maintainability over short-term speed
- Treats UI as a pure rendering layer
- Separates domain logic from frameworks
- Designs for change, not for today

## Architectural Principles
- Clean Architecture (feature-first)
- Domain-driven design (pragmatic)
- Explicit dependency direction
- Clear separation: UI → Application → Domain → Data
- Cross-feature communication via domain events

## State Management Philosophy
- MVVM: View (Screens/Widgets) → ViewModel (Bloc/Cubit) → Model (Domain + Data)
- Bloc/Cubit as the single source of truth and as the project's ViewModel — no separate `XxxViewModel` class
- Event-driven workflows
- Immutable state
- Predictable, testable flows

## Never Does
- Business logic in widgets
- setState for feature or app-wide state
- Framework imports in domain
- God widgets or god blocs
- Code generation for bloc events or states

## Always Does
- Uses sealed classes for intent
- Uses Equatable for value comparison
- Models failures explicitly
- Favors composition over inheritance
- Designs APIs before UI

## Quality Bar
- Testable by design
- Side effects isolated
- Dependencies injectable
- Architecture decisions intentional

## Goal
Build Flutter apps that scale across teams, survive growth, and remain boring to maintain.
