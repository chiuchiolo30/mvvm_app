# Quickstart: pokemon_list

> Para QA, developers nuevos y validacion post-deploy.

---

## Precondiciones

- [ ] Ejecutar `flutter pub get`.
- [ ] Tener conexion a internet para consumir PokeAPI.
- [ ] Iniciar la app con `flutter run`.
- [ ] La pantalla inicial debe ser `PokemonListScreen`.

---

## Escenario 1 — Carga inicial de Pokemon

1. Abrir la app.
2. Observar la pantalla `Pokemon`.
3. Esperar a que termine el loading inicial.
4. Verificar que se muestren tarjetas de Pokemon.

**Resultado esperado:** la app solicita la primera pagina con `limit=20` y `offset=0`, muestra una grilla/lista de tarjetas y cada item incluye nombre, numero de Pokedex y artwork.

Acceptance criteria cubiertos: AC1, AC2, AC4.

---

## Escenario 2 — Paginacion automatica

1. Abrir la app con conexion a internet.
2. Esperar a que cargue la primera pagina.
3. Hacer scroll hasta acercarse al final del listado.
4. Observar el footer inferior mientras carga la siguiente pagina.
5. Esperar a que se agreguen nuevos Pokemon a la lista.

**Resultado esperado:** la lista existente permanece visible, aparece un indicador inferior durante la carga y se agregan nuevos items sin duplicar requests en vuelo.

Acceptance criteria cubiertos: AC3, AC5.

---

## Escenario 3 — Fin de paginacion

1. Usar un entorno controlado o fake de repository que devuelva una pagina con `hasNextPage=false` y `nextOffset=null`.
2. Renderizar la pantalla con items existentes.
3. Hacer scroll al final.

**Resultado esperado:** no aparece spinner, no aparece error y no se intenta cargar otra pagina.

Acceptance criteria cubiertos: AC9.

---

## Escenario 4 — Error en carga inicial

1. Desactivar la conexion de red o usar un fake que devuelva `PokemonListNetworkFailure` en la primera carga.
2. Abrir la app.
3. Esperar a que falle la carga inicial.
4. Verificar el estado de error.
5. Restaurar red o cambiar el fake a respuesta exitosa.
6. Presionar `Reintentar`.

**Resultado esperado:** se muestra un mensaje humano, sin stack traces ni errores tecnicos, con accion de reintento. Al reintentar, vuelve a ejecutar la carga inicial.

Acceptance criteria cubiertos: AC6.

---

## Escenario 5 — Error durante paginacion

1. Cargar correctamente la primera pagina.
2. Simular fallo de red o fake failure solo para la siguiente pagina.
3. Hacer scroll al final.
4. Verificar el footer inferior.
5. Restaurar la respuesta exitosa.
6. Presionar `Reintentar carga`.

**Resultado esperado:** la lista ya cargada permanece visible y usable, el spinner inferior se reemplaza por un retry inline y el reintento vuelve a pedir la pagina pendiente.

Acceptance criteria cubiertos: AC7.

---

## Escenario 6 — Estado vacio

1. Usar un fake de repository que devuelva `PokemonPage(items: [], hasNextPage: false, nextOffset: null)` para la primera pagina.
2. Abrir la pantalla.
3. Esperar a que termine la carga inicial.

**Resultado esperado:** se muestra el mensaje `No hay Pokemon para mostrar` con una accion `Reintentar`.

Acceptance criteria cubiertos: AC8.

---

## Escenario 7 — Imagen rota o no disponible

1. Usar un fake de repository que devuelva un `PokemonListItem` con `artworkUrl` invalida.
2. Abrir la pantalla.
3. Esperar a que el item se renderice.

**Resultado esperado:** el item sigue visible y usable; en lugar de la imagen rota se muestra el placeholder con icono de Pokemon.

Acceptance criteria cubiertos: AC10.

---

## Escenario 8 — Formato de nombre y numero

1. Usar respuesta real o fake con nombres como `mr-mime` y `deoxys-normal`.
2. Verificar los textos renderizados en las tarjetas.
3. Verificar el numero de Pokedex.

**Resultado esperado:** los nombres se muestran como `Mr Mime` y `Deoxys Normal`; el numero se muestra con formato `#001`, `#025`, etc.

Acceptance criteria cubiertos: AC2.

---

## Validacion tecnica

Ejecutar antes de considerar la feature lista:

```bash
flutter test
flutter analyze lib test
dart run tools/architecture_check.dart
dart run tools/technical_debt_metrics.dart --path lib
dart run tools/technical_debt_metrics.dart --path lib --compare-baseline
```

---

## Notas

- PokeAPI no requiere autenticacion.
- La feature no incluye detalle, busqueda, filtros, favoritos ni cache offline.
- Si se incorpora un Design System formal, migrar spacing y dimensiones de UI a tokens/DSResponsive.
