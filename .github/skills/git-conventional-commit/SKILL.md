# Git Conventional Commit Skill

Este proyecto utiliza **Conventional Commits v1.0.0**.

Todos los commits deben respetar estrictamente esta convención.

## Formato obligatorio
<type>(<context>:<feature>): <description>

Ejemplo:
feat(app-food_menu:login): agrega validación de refresh token
fix(app-remitos-app-new:menu): corrige ranking de combinaciones
refactor(core_network:events): simplifica event bus


---

# Types permitidos
feat
fix
docs
style
refactor
perf
test
build
ci
chore
revert

---

# Scope jerárquico

El scope debe usar el formato:

<context>:<feature>

El context se determina automáticamente según la carpeta del proyecto.

---

## context = apps

Si el cambio ocurre dentro de:

apps/<app_name>/

El context debe ser:

app-<app_name>

Ejemplos:

feat(app-food_menu:ranking)
fix(app-remitos-app-new:sync)
refactor(app-volumetria_app:map)

---

## context = packages

Si el cambio ocurre dentro de:

packages/<package_name>/

El context debe ser el nombre del paquete.

Ejemplos:

feat(core_network:client)
fix(design_system:button)
refactor(domain:entity)

---

## detección de feature

La feature se determina a partir del módulo o carpeta principal modificada dentro del contexto.

Ejemplos:

apps/food_menu/lib/features/ranking/
→ feature: ranking

apps/food_menu/lib/auth/
→ feature: auth

packages/design_system/lib/button/
→ feature: button

packages/core_network/lib/client/
→ feature: client

Si no se puede determinar una feature específica, usar el nombre del módulo principal.

### prioridad para detectar feature

La feature debe inferirse con este orden de prioridad:

1. `lib/features/<feature_name>/`
2. `lib/<module_name>/`
3. carpeta principal inmediatamente debajo del contexto
4. si no hay una feature clara, usar `general`

Ejemplos:

apps/food_menu/lib/features/ranking/
→ feature: ranking

packages/design_system/lib/components/button/
→ feature: button

packages/core_network/lib/
→ feature: general

---

## agrupación de cambios

Los archivos modificados deben agruparse por contexto antes de generar commits.

Reglas:

1. agrupar archivos por carpeta raíz:

apps/<app_name>/
packages/<package_name>/

2. cada grupo genera un commit independiente.

3. si un mismo contexto tiene cambios en múltiples features,
el agente puede generar múltiples commits dentro del mismo contexto.

Ejemplo:

apps/food_menu/lib/features/menu/
apps/food_menu/lib/features/ranking/

→ generar dos commits:

feat(app-food_menu:menu)
feat(app-food_menu:ranking)

---

## cambios globales

Si el cambio afecta al monorepo completo:

monorepo

Ejemplo:

ci(monorepo:melos): agrega bootstrap automático

# Reglas para la descripción

La description debe:

- estar en minúsculas
- ser breve
- no terminar con punto
- describir el cambio real

El commit debe contener solo la línea de subject. No se usa body salvo en Breaking Changes.

Ejemplo:
feat(app-food_menu:menu): agrega sistema de ranking por estrellas


---

# Breaking Changes

Si hay un breaking change:
feat(core_network:auth)!: cambia contrato de autenticación


y opcionalmente agregar footer:

BREAKING CHANGE: el endpoint ahora requiere refresh_token


---

# Flujo de commit

El agente debe:

1. Ejecutar `git status`
2. Revisar los `diff` por contexto (apps/ vs packages/)
3. Determinar type correcto
4. Determinar scope según la carpeta
5. Generar commit message
6. Si hay cambios en múltiples contextos, hacer commits separados (ver sección abajo)

Un commit no debe mezclar cambios de apps/ y packages/. Si ocurre, deben separarse en commits diferentes.

7. Ejecutar por cada grupo de cambios:
```
git add <archivos del contexto>
git commit -m "<mensaje>"
```
8. Detectar todos los remotes configurados usando:
```
git remote
```
Luego realizar push a cada remote configurado. Ejemplo:
```
git push gitea HEAD
git push origin HEAD
```

Si existen múltiples remotes, el agente debe empujar los commits a todos ellos.

Si no hay cambios:
No hay cambios para commitear.

---

## cambios en múltiples contextos

Si hay cambios en más de un contexto, se deben hacer commits separados por contexto.
Nunca usar `git add -A` ni `git add .` cuando los cambios abarcan múltiples contextos.

Ejemplo:
```
git add apps/food_menu/
git commit -m "feat(app-food_menu:ranking): agrega sistema de estrellas"

git add packages/design_system/
git commit -m "fix(design_system:button): corrige color en modo oscuro"

git remote | xargs -I{} git push {} HEAD
```

Si todos los cambios pertenecen a un único contexto, se puede usar:
```
git add <carpeta_del_contexto>/
git commit -m "<mensaje>"
git remote | xargs -I{} git push {} HEAD
```

# Validación del commit

Antes de ejecutar el commit el agente debe verificar:

- que el mensaje cumple Conventional Commits
- que el scope coincide con la estructura del repositorio
- que la description describe realmente el diff

Si el mensaje no cumple las reglas, debe regenerarlo.

---

## commits inválidos

No se permiten commits con descripciones genéricas como:

update
changes
fix bugs
misc
stuff
varios cambios

Si el mensaje generado es genérico o no describe el cambio real,
el agente debe regenerar el commit message.