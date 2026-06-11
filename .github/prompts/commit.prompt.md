---
agent: 'agent'
description: 'Realiza commit del archivo indicado siguiendo Conventional Commits'
---

Usa la skill **Git Conventional Commit Skill**.

Objetivo:
Realizar commit únicamente del archivo indicado.

Parámetro esperado:
/commit <ruta_del_archivo>

Ejemplo:
/commit apps/food_menu/lib/features/ranking/presentation/ranking_page.dart


Pasos:

1. Verificar si el archivo tiene cambios.
2. Revisar el diff del archivo.
3. Determinar `type`, `context` y `feature`.
4. Generar commit message siguiendo Conventional Commits.
5. Ejecutar:
git add <archivo>
git commit -m "<mensaje>"
git push


Reglas:

- no incluir otros archivos
- seguir estrictamente la **Git Conventional Commit Skill**
- validar Conventional Commits
- si el archivo no tiene cambios mostrar: "No hay cambios en el archivo indicado."
