# Sherry's Midnight Apothecary — Agent Working Rules

## Canonical project root

This repository has an outer workspace directory and one nested Godot project.

- Repository/workspace root: the directory containing this `AGENTS.md` and `.git/`.
- **Canonical Godot project root:** `sherry’s-midnight-apothecary/` (curly apostrophe `’`).
- `project.godot`, `README.md`, game source, assets, tests, tools, and project documentation all belong under the canonical Godot project root.
- Unless a task explicitly targets repository-level metadata, **do not create game files, notes, generated assets, scripts, or temporary files beside `AGENTS.md`**.
- Run Godot commands from `sherry’s-midnight-apothecary/`, or pass that directory to `--path`.

Before adding a file, read `sherry’s-midnight-apothecary/docs/PROJECT_STRUCTURE.md` and choose the documented destination. If no destination fits, ask before inventing a new top-level directory.

## Architecture boundaries

- `app/` owns the persistent `AppRoot` and the minimal day/night `GameFlow`.
- `shared/` owns cross-runtime data and reusable systems. Keep shared APIs small and explicit.
- `day/` owns daytime exploration; `night/` owns nighttime alchemy/shop gameplay.
- `menu/` owns the title/menu presentation. `minigames/` owns isolated minigame modules.
- Static definitions are Godot Resources in `shared/definitions/` and are referenced explicitly.
- Do not introduce an event bus, global world state, automatic Resource registry, duplicate scene-flow service, or persistent cross-scene node references without explicit approval.
- `AppRoot`, `GameFlow`, `PlayerData`, `DayResult`, `NightResult`, and `project.godot` are shared integration contracts; change them conservatively.

## Placement rules

- Keep a feature's `.gd`, `.tscn`, `.tres`, shaders, and feature-specific art near that feature where practical.
- Put broadly reused raw/presentation art in `art/`, shared audio in `audio/`, and shared gameplay/UI code in `shared/`.
- Put automated tests and fixtures in `tests/`; do not place test scenes in production feature folders.
- Put developer scripts in `tools/`; tools must write scratch data to `tmp/` and deliberate deliverables/previews to `outputs/`.
- `docs/` is for maintained project documentation. Do not scatter planning Markdown through source folders unless it documents that folder specifically.
- `addons/` is third-party/editor-plugin code. Avoid editing it unless the task explicitly concerns that plugin.
- `.godot/`, `tmp/`, `outputs/`, `dist/`, `__pycache__/`, and generated/imported artifacts are not production source locations.
- Never create another nested Godot project or copy a complete prototype into production paths. Prototype/reference projects may exist only under `tools/` and must remain isolated.
- Treat `game/`, `assets/`, and `examples/` as legacy/compatibility areas: inspect existing references before editing, and do not add new features there by default.

## Editing and verification

- **Autonomous execution**: Do not block to ask for user confirmation before making code edits or running implementations. Directly apply changes, execute verification tests, and report results concisely.
- Preserve existing user changes and avoid unrelated cleanup or bulk file moves.
- Use `res://` paths rooted at `sherry’s-midnight-apothecary/`; never encode absolute local filesystem paths in Godot resources.
- Keep `.gd.uid` files paired with their scripts when Godot has generated them. Do not hand-create import-cache files.
- When moving a Godot resource, update all `res://` references in the same change and verify parsing.
- Every time a feature is added or its player-visible behavior, controls, data flow, or architecture changes, update the relevant Markdown documentation in `sherry’s-midnight-apothecary/docs/` in the same change. If no suitable feature document exists, create one there and add it to `docs/FEATURES.md`; do not consider the feature complete while its documentation is stale.
- Minimum validation from the Godot project root:

```powershell
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/run_tests.gd
```

Use the narrowest relevant test during iteration, then run both commands above for changes that affect shared contracts or project structure. If `godot` is unavailable, report that validation was not run.

