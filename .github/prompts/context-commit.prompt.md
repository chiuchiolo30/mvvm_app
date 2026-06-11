---
agent: 'agent'
description: 'Realiza commit de todos los cambios de un contexto específico (app, package o monorepo)'
---

Usa la skill **Git Conventional Commit Skill**.

Objetivo:
Realizar commit inteligente de todos los cambios que pertenezcan al contexto indicado.

Parámetro esperado:
/context-commit <contexto>

Donde `<contexto>` puede ser:
- El nombre de una app: `remitos-app-new`, `food_menu`, `productos_cirugia`, etc.
- El nombre de un package: `core_network`, `design_system`, `domain`, etc.
- La palabra `monorepo` para archivos raíz (melos.yaml, pubspec.yaml, .github/, etc.)

Ejemplos:
/context-commit remitos-app-new
/context-commit design_system
/context-commit monorepo

Pasos:

1. Ejecutar `git status` para detectar todos los archivos modificados o sin trackear.
2. Filtrar únicamente los archivos que pertenezcan al contexto indicado:
   - Si es una app: `apps/<contexto>/`
   - Si es un package: `packages/<contexto>/`
   - Si es `monorepo`: archivos en la raíz del repositorio (melos.yaml, pubspec.yaml, .github/, .agents/, .claude/, etc.)
3. Si no hay cambios en ese contexto, mostrar: "No hay cambios en el contexto '<contexto>'." y detener.
4. Revisar los `diff` de esos archivos.
5. Agrupar cambios por feature dentro del contexto según la skill.
6. Determinar el `type`, `context` y `feature` para cada grupo.
7. Si hay múltiples features, generar commits separados.
8. Ejecutar los commits.
9. Al finalizar, realizar `git push`.

Reglas:

- solo procesar archivos del contexto indicado, ignorar el resto
- seguir estrictamente la **Git Conventional Commit Skill**
- no modificar archivos
- no crear commits genéricos
- validar que el mensaje cumpla Conventional Commits