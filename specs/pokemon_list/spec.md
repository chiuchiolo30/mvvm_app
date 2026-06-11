# SPEC — pokemon_list

## Metadata

| Field | Value |
|---|---|
| Feature | `pokemon_list` |
| Level | Standard |
| Status | Draft — pending approval |
| Data source | [PokeAPI](https://pokeapi.co/) — `https://pokeapi.co/api/v2/pokemon` |

---

## 1. Functional Objective

Show the user a scrollable list of all Pokémon, with name and artwork, fetched from PokeAPI. The list must support pagination (infinite scroll) since PokeAPI exposes 1000+ entries.

This is a reference/demo feature used to validate a project's architecture governance end-to-end (domain, data, UI, DI, validation, baseline). The implementation must follow whatever architecture contract the target project defines — this spec only describes the functional behavior, not the technical structure.

---

## 2. User Stories

- **US1**: As a user, I want to see a list of Pokémon when I open the screen, so I can browse them.
- **US2**: As a user, I want to see each Pokémon's name and artwork, so I can identify them visually.
- **US3**: As a user, I want the list to load more Pokémon automatically as I scroll, so I don't have to navigate pages manually.
- **US4**: As a user, I want to see a loading indicator while data is being fetched, so I know the app is working.
- **US5**: As a user, I want to see a clear error message with a retry option if the data fails to load, so I can recover without restarting the app.
- **US6**: As a user, I want to see a clear message if there is no data to show, so I'm not confused by a blank screen.

---

## 3. Acceptance Criteria

| ID | Criterion |
|---|---|
| AC1 | On first entering the screen, the app requests the first page of Pokémon from PokeAPI (`GET /pokemon?limit=20&offset=0`). |
| AC2 | Each list item shows the Pokémon's **name** (formatted, see Business Rules) and its **artwork image**. |
| AC3 | When the user scrolls near the end of the list, the next page is requested automatically (`offset += limit`), without duplicating in-flight requests. |
| AC4 | While the first page is loading, the screen shows a **loading state** (no list, no error). |
| AC5 | While a subsequent page is loading, the screen shows the existing list plus a **small loading indicator at the bottom**. |
| AC6 | If the initial request fails (network/API error), the screen shows an **error state** with a human-readable message and a **retry** action. |
| AC7 | If a pagination request fails, the existing list remains visible, the bottom loading indicator is replaced by an **inline retry** affordance, and the rest of the list stays usable. |
| AC8 | If the API returns zero results for the first page, the screen shows an **empty state** with a guiding message. |
| AC9 | When the API's `next` field is `null`, pagination stops silently (no spinner, no error). |
| AC10 | If a Pokémon's artwork image fails to load, a placeholder image/icon is shown instead — the item remains usable. |

---

## 4. Edge Cases

- API unreachable / timeout on first load → error state (AC6).
- API unreachable / timeout on pagination → inline retry (AC7), list above stays intact.
- Empty result set on first page → empty state (AC8).
- Reaching the last page (`next == null`) → stop pagination cleanly (AC9).
- User scrolls fast and triggers multiple "load next page" events before the previous request resolves → must be debounced/guarded so only one pagination request is in flight at a time.
- Pokémon name contains a hyphen (e.g. `deoxys-normal`, `mr-mime`) → must be formatted for display (see Business Rules).
- Broken or missing sprite URL for a given Pokémon → placeholder image (AC10).

---

## 5. Business Rules

- **Data source**: PokeAPI REST API, base URL `https://pokeapi.co/api/v2/`.
- **List endpoint**: `GET /pokemon?limit=20&offset={offset}` → returns `{ count, next, previous, results: [{ name, url }] }`.
- **Pagination**: `limit = 20`. Start at `offset = 0`. Use the response's `next` field (or `count`) to determine if more pages exist. `next == null` → no more pages.
- **Pokémon ID**: each `result.url` has the form `https://pokeapi.co/api/v2/pokemon/{id}/`. The `{id}` (Pokédex number) must be extracted from this URL.
- **Artwork URL**: built from the extracted ID using the official artwork sprite pattern:
  `https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/{id}.png`
  (No extra HTTP call to the detail endpoint is required for the list.)
- **Name formatting**: PokeAPI names are lowercase, hyphen-separated (e.g. `mr-mime`). For display, replace `-` with a space and capitalize each word (e.g. `Mr Mime`, `Deoxys Normal`).
- **Pokédex number display**: shown as `#001`, `#025`, etc. (zero-padded to 3 digits) — derived from the same extracted ID.

---

## 6. UX Restrictions

The screen MUST implement all states:

- **Initial**: nothing has been requested yet (transient, immediately followed by loading).
- **Loading**: shown on first load only — full-screen loading state (no content, no error).
- **Success**: grid or list of Pokémon cards (artwork + name + Pokédex number).
- **Loading more**: success state + small loading indicator at the bottom of the list while fetching the next page.
- **Empty**: guiding message, shown only if the first page returns zero results.
- **Error**: human-readable message + retry button, shown if the first page fails. Pagination errors use an inline retry instead of replacing the whole screen.

General UX rules:

- No technical error messages or stack traces shown to the user.
- No hardcoded colors/sizes — use the target project's Design System tokens if it has one, or its `Theme` consistently otherwise.
- List/grid items must be visually consistent (equal sizing, consistent spacing).
- Images must have a fixed aspect ratio with a placeholder while loading or on error.

---

## 7. Technical Capabilities Needed

This feature requires the target project to provide the following capabilities, using whatever packages/conventions its own architecture governance defines:

- Async state management covering at least: loading, success, empty, error and "loading more" states.
- An HTTP client capable of GET requests with query parameters, to consume the PokeAPI REST endpoint.
- Dependency injection wiring across datasource → repository → use case → presentation layer.
- Typed, functional-style error handling (a `Result`/`Either`-like type) to model recoverable failures.
- Image loading with placeholder/fallback support for broken or missing artwork URLs.
- Navigation: **not required** for this feature (single screen, no navigation flow yet).

---

## 8. Out of Scope

- Pokémon detail screen (tap on an item to see stats, types, abilities, etc.) — candidate for a future feature (`pokemon_detail`).
- Search / filter by name or type.
- Favorites / persistence (local storage).
- Offline caching of results.

---

## 9. Open Questions

- None at the moment. Default decisions documented above (pagination size, artwork URL pattern, name formatting) are assumed unless corrected during review.
