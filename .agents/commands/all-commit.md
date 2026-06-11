# /all-commit

Usa la skill **Git Conventional Commit Skill**.

Objetivo:
Realizar commit inteligente de todos los cambios del repositorio.

Pasos:

1. Ejecutar `git status` para detectar archivos modificados.
2. Revisar los `diff`.
3. Agrupar cambios por contexto según la skill:
   - apps/<app_name>
   - packages/<package_name>
4. Determinar el `type`, `context` y `feature`.
5. Generar commits siguiendo Conventional Commits.
6. Si existen múltiples contextos, crear commits separados.
7. Ejecutar los commits.
8. Al finalizar, realizar `git push`.

Reglas:

- seguir estrictamente la **Git Conventional Commit Skill**
- no modificar archivos
- no crear commits genéricos
- validar que el mensaje cumpla Conventional Commits
- si no hay cambios mostrar:
