# Golden Cliff（烁金横崖）— standalone day level

`res://day/levels/golden_cliff/` is a standalone day level under the `DayRuntime`
architecture (same shape as the standalone forest interior level). The pack keeps
its own scenes, scripts, and art inside the folder; it creates no nested Godot
project, Autoload, event bus, or persistent cross-scene references.

## Deployment status

Registered in `DayRuntime.LEVELS` in `res://day/day_runtime.gd` (NOT in
`DAILY_LEVELS`). Deployment steps are documented in
`day/levels/golden_cliff/README_DEPLOY.md`.

## Global console (DeveloperConsole)

The standalone DeveloperConsole is embedded directly in `golden_cliff.tscn`:

- `DebugUI` — `CanvasLayer`, `layer = 200` (above gameplay).
- `DebugUI/DeveloperConsole` — instanced from
  `res://night/ui/developer_console/developer_console.tscn`.

This matches the standalone-level pattern used by lake/lakebed/raintree/town.
`day_level_environment.gd` (the scene root) keeps the embedded console active in
standalone runs and disables it when the level runs under `DayRuntime` (which owns
its own console layer). The console hides itself on `_ready()` and toggles via the
project's usual key bindings.

## Title UI (SceneTitleCard)

`golden_cliff.tscn` does NOT embed `SceneTitleCard` — the title card is
`DayRuntime`-owned. The level only registers `golden_cliff_level.tres` in
`DayRuntime.LEVELS`; DayRuntime presents the global `SceneTitleCard` using that
resource's `disaster_name` / `normal_description` (see `docs/scene_title_card.md`).
`show_title_card = true` is set on the level resource.

## B-key backpack & ESC pause menu

The global `PauseMenu` (`res://night/ui/pause_menu/pause_menu.tscn`, the same
scene AppRoot hosts in `GlobalUI`) is embedded in `golden_cliff.tscn` so the
standalone showcase level is self-contained:

- `PauseMenuLayer` — `CanvasLayer`, `layer = 200`, script
  `day/levels/golden_cliff/pause_menu_host.gd`.
- `PauseMenuLayer/PauseMenu` — instanced from `pause_menu.tscn` (starts hidden;
  pages: SETTINGS / CODEX / BACKPACK / HELP).

`pause_menu_host.gd` mirrors `app_root._unhandled_input` for standalone runs:

- **B (`open_backpack`)** opens the menu on the BACKPACK page — the potion/items
  inventory bound from `DayLevelEnvironment.get_player_data()` (the same shared
  `PlayerData` instance the PotionThrower and hotbar use).
- **ESC (`ui_cancel`)** opens the pause menu (SETTINGS page by default). While
  open the menu handles ESC/B itself (B toggles between the backpack and the
  previous page, ESC closes) and the tree is paused (`get_tree().paused`).
- Guards `day_modal_input_locked` and LineEdit/TextEdit focus, exactly like
  `app_root.gd`.

When the level runs under `DayRuntime` (via AppRoot), `day_level_environment.gd`
disables the embedded `PauseMenuLayer`/`PauseMenu` (same branch that disables the
embedded DebugUI console); AppRoot's global `GlobalUI/PauseMenu` handles B/ESC
there instead. The `PauseMenu` is fully standalone-safe: its settings service is
null-guarded when unbound, and its inventory page handles an empty fresh
`PlayerData`.

## LevelData

`day/levels/golden_cliff/golden_cliff_level.tres`:

- id: `golden_cliff`, display name `烁金横崖`
- disaster: `断衡之灾` (corrupted by default, `start_corrupted = true`)
- default entry: `EntryPoints/default`; extra entries: `from_south`, `from_lake`
- exit portal: `home/default` via `DoorPortal` (goes through `DayRuntime.switch_to_level()`)
- content scene: `golden_cliff.tscn`, root script `day_level_environment.gd`

## Core gameplay

1. The yellow spiritual-vein "balance break" corrupts the cliff; rock weights go
   wrong (floating boulders, collapsing platforms, fall damage into the abyss).
2. Three balance-stone mechanisms are `StaticBody2D` nodes implementing
   `receive_potion_hit(hit)`; each direct potion hit performs one calibration and
   each mechanism needs two hits.
3. When all three balance stones are stable the root `DayLevelEnvironment` switches
   to the uncorrupted state and the exit portal unlocks.
4. Runtime effects are Godot-native (no sprite sheets): sine-motion
   `AnimatableBody2D` floaters, `Area2D` collapse warnings with Tween shake/fall,
   runtime `Polygon2D` debris, `Line2D` hit rings and portal-repair sparks,
   `Parallax2D` background.

## Validation

From the project root (replace `godot` with your Godot 4.6 console executable):

```powershell
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/golden_cliff_smoke_test.gd
```

The smoke test instantiates `golden_cliff.tscn` (loading `day_runtime.tscn` first,
in the game's real load order), asserts the embedded `DebugUI`/`DeveloperConsole`
and `PauseMenuLayer`/`PauseMenu` wiring, asserts the `golden_cliff` LevelData is
registered in `DayRuntime.LEVELS` with title-card data set, and simulates B-key
(backpack page opens) and ESC (menu closes, tree unpauses) keypresses. Simulated
key events set both `keycode` and `physical_keycode` (Godot 4.6 `is_action_pressed`
is event-based).
