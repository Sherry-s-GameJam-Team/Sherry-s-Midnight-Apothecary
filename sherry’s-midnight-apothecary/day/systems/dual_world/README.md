# Dual-world pure-scene system

This directory provides the reusable Sherry/Luca dual-world layer. It is opt-in: no production `LevelData`, normal level scene, `DayRuntime`, player asset, camera script, pause UI, or save schema was replaced.

## Runtime architecture

`DualWorldManager` owns `CORRUPTED` / `ORIGINAL`, world visibility, exclusive world collision, the fade midpoint, and `world_changed`. `DualProtagonistController` owns `SHERRY` / `LUCA`, the Q action, the project-specific actor adapter, camera target changes, and the pre-switch overlap guard. `DualWorldState` is a level-local key/value signal store for puzzle mechanisms; it is intentionally not added to the global save.

The expected level tree is:

```text
DualWorldLevel
├── SharedWorld
│   ├── Background
│   ├── SharedVisual
│   ├── SharedCollision
│   └── SharedInteractables
├── CorruptedWorld
│   ├── Visual
│   ├── Collision
│   └── WorldObjects
├── OriginalWorld
│   ├── Visual
│   ├── Collision
│   └── WorldObjects
├── Actors
│   ├── Sherry
│   └── Luca
└── Systems
    ├── DualWorldState
    ├── DualWorldManager
    └── DualProtagonistController
```

Both world roots must stay at `(0, 0)`. World art uses `Sprite2D`, `AnimatedSprite2D`, or `Polygon2D`; terrain uses `StaticBody2D` plus `CollisionShape2D`/`CollisionPolygon2D`. Do not add `TileMap` or `TileMapLayer`.

## Project adapter

The current Sherry is composed directly inside each day level rather than exposed as one production `PackedScene`. The test therefore uses `sherry_dual_world_actor.tscn`, which composes the unchanged production controller `day_player_controller.gd`, production outdoor collision, production presentation, and a normal existing-style child `Camera2D`. It does not copy movement code or the Demo placeholder.

Sherry has no public input-enable property. The controller adapter disables only Sherry's physics and input callbacks and clears velocity; it never changes movement constants. Luca's existing `input_enabled` and `stop_moving()` API is used. The inactive actor remains instantiated at its own position, while its actor collision shapes are disabled so it cannot contact the active world's terrain or triggers.

The test reuses Sherry's child `Camera2D` and reparents that same camera to the active actor at the world-switch midpoint. Normal levels keep their current parent-follow camera behavior.

## Creating a dual-world level

1. Duplicate the structure in `res://day/levels/_tests/dual_world/dual_world_puzzle_demo.tscn`.
2. Author Corrupted and Original as separate `Node2D` scenes rooted at `(0, 0)`, with `Visual`, `Collision`, and `WorldObjects` children.
3. Keep the shared markers `Origin`, `LevelStart`, `GroundBase`, `PuzzleAnchor01`, `PuzzleAnchor02`, and `LevelEnd` at identical world coordinates.
4. Assign both world paths and the optional transition `ColorRect` to `DualWorldManager`.
5. Assign Sherry, Luca, the existing level camera, and manager paths to `DualProtagonistController`.
6. Connect mechanism scripts to `DualWorldState.state_changed`. If state conditionally disables terrain, also listen to `world_collision_prepared` and reapply that condition after the manager prepares a world, as the whitebox does.
7. Keep puzzle data local unless a future production level explicitly maps selected keys into the existing `PlayerData`/`SaveService` schema.

The switch guard briefly prepares the target world's collision, queries the target actor's saved collision shape at its current transform, and rejects the switch if a target-world body overlaps. It restores the hidden world's collision after a rejected check and never relocates the actor.

## Editor alignment

Open `corrupted_alignment_preview.tscn` to edit/inspect Corrupted over a 0.25-alpha Original ghost, or `original_alignment_preview.tscn` for the reverse. `DualWorldGhostReference` is `@tool`; it creates the ghost as an internal editor-only child, disables all processing and collision, and never serializes it into the level. Separate preview scenes avoid a Corrupted↔Original cyclic dependency.

## Whitebox test

Run:

```powershell
godot --path . res://day/levels/_tests/dual_world/dual_world_puzzle_demo.tscn
```

Use A/D or arrows to move, W/Z/up to jump, Q to switch, and Esc to reset. Switch to Luca, cross the blue intact bridge, touch the anchor, switch back to Sherry, cross the newly stabilized violet bridge, touch the seal, then pass the opened shared gate to `LevelEnd`.

Automated checks:

```powershell
godot --headless --path . res://tests/dual_world_runtime_test.tscn
godot --headless --path . --script res://tests/run_tests.gd
```
