# Crimson Vale Platforming Challenge (绯红绝谷·血叶断崖)

The Crimson Vale Challenge (`CrimsonValeChallenge`, `res://day/levels/Crimson Vale/crimson_vale_challenge.tscn`) is a horizontal platforming obstacle course and gauntlet scene built entirely with the art, hazard, and VFX assets from `day/levels/Crimson Vale/`.

## Gameplay & Level Design

- **Terrain & Traversal**:
  - 3-tier vertical and horizontal route spanning 4800px.
  - **Section 1: Wind-carved Cliffs (风蚀断崖)**: Initial jump ascent over broken floating rock ledges (`broken_ground.png`, `ground_2.png`).
  - **Section 2: Village Rooftop & Eaves Leap (枫村绝壁飞檐)**: High-altitude platforming across shop canopies (`shop.png`) and house roofs (`house.png`) with one-way drop-through platforms.
  - **Section 3: Ruined Bridge & Danxin Gate (残破古石桥与丹心门)**: Stepping stones across the misty abyss towards the restored Danxin Gate portal (`丹心门_修复态.png`).
  - **Secrets & Physics Props**: Interactive Wind Chime (`res://day/levels/Crimson Vale/props/wind_chime.tscn`) hidden on high rafters. Features stationary `风铃.png` frame with 7 individual oscillating chime pieces (`p1.png` - `p7.png`) simulating physical pendulum collisions with player brushing velocity, ambient breeze, and potion wind.

## Blood Leaf Swarm Threat & Foreground Shelter Stealth

- **Blood Leaf Swarm Hazards (`BloodLeafSwarm`)**:
  - Three swarms guard key platforming choke points with active delayed tracking (0.55s delay) and aggressive cyclone dive attacks.
- **Foreground Mask / Shelter Hiding (`ForegroundShelter`)**:
  - Reusable component: `res://day/levels/Crimson Vale/hazards/foreground_shelter.tscn` with script `foreground_shelter.gd`.
  - Places high-z foreground props (`z_index = 20`, e.g. `晒枫脂架.png` drying racks and house eaves) that physically mask the player.
  - **Stealth / Lock-breaking Mechanic**:
    - Stepping into a shelter sets `player.set_meta("sheltered", true)` and adds the player to the `"sheltered"` group.
    - Player visually shifts to a shadowed stealth tone (`modulate = Color(0.68, 0.76, 0.92, 0.78)`).
    - Any pursuing `BloodLeafSwarm` **instantly loses target lock**, cancels its attack telegraph/dive, and enters a harmless `COOLDOWN` / `IDLE` state hovering outside the shelter.
    - The swarm cannot damage or target the player while sheltered.
    - Exiting the shelter into the open clears the sheltered status and enables swarms in range to resume hunting.

## Fall Protection & Checkpoints

- **Abyss Hazard (`AbyssHazard`)**:
  - Spans the lower gap (`Y = 840`).
  - Falling into the abyss deals 1 HP fall damage and automatically respawns Sherry at the last visited `ForegroundShelter` checkpoint with momentary invulnerability fade.

## Integration & Verification

- **Level Resource**: `res://day/levels/Crimson Vale/crimson_vale_challenge_level.tres`.
- **Portal Link**: Accessible via `ChallengePortal` in `crimson_vale.tscn` and returns through `ExitPortal` or `DanxinGate`.
- **Test Suites**:
  - `res://tests/run_crimson_vale_challenge_test.gd` (Validates shelters, swarms, stealth lock-breaking, and checkpoint respawning).
  - `res://tests/run_blood_leaf_swarm_test.gd` (Validates particle shader, foreground/background layering, and potion responses).
