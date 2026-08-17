# Blood Leaf Swarm Hazard (血叶攻击系统)

The Blood Leaf Swarm (`BloodLeafSwarm`) is a reusable environmental threat and combat hazard designed for the "Crimson Vale / 绯红绝谷" disaster scene and other corrupted autumn environments.

## Visual presentation

- **Particle Shader**: Powered by `res://day/levels/Crimson Vale/shaders/blood_leaf_swarm.gdshader`, using `GPUParticles2D` in world coordinates (`local_coords = false`).
- **Maple Leaf Textures**:
  - `LeafParticlesA` (amount = 160) uses `res://day/levels/Crimson Vale/maple1.png` with larger scales, higher brightness, and faster swirl.
  - `LeafParticlesB` (amount = 120) uses `res://day/levels/Crimson Vale/maple.png` with deeper crimson tints, smaller sizes, and intensified fluttering.
- **Flight & Fluttering Dynamics**:
  - Spawns distributed across a ring rather than a single point.
  - Initial tangential speed produces a swirling "chaotic dance" ("乱舞").
  - Inward attraction + cyclone swirl around target center.
  - 3D fluttering rotation simulated via trigonometric scale oscillations on particle transforms.

## Delayed tracking mechanic

- **Tracking Delay**: Rather than locking onto the player's instant coordinates, the swarm tracks the player's historical position from `tracking_delay` seconds ago (default `0.55s`, customizable in `0.05s ~ 2.0s`).
- When the player dashes or changes directions abruptly, the swarm continues swarming toward the previous position before curving to follow the updated trail.

## Lifecycle & State Machine

1. **`IDLE`**:
   - Swarm gently hovers/swirls around its spawn location at base opacity (`alpha = 0.8`), visible to the player from afar.
   - When the player enters `detection_radius` (default 650px), the swarm wakes up and enters `TELEGRAPH`.
2. **`TELEGRAPH`** (0.6 ~ 0.8s):
   - Swarm gathers at the spawn location with intensified swirling particles.
   - `Telegraph` node renders an animated, rotating segmented warning ring.
   - `DamageArea` is inactive (`monitoring = false`).
3. **`TRACKING`** (default `4.0s`):
   - `DamageArea` activates (`monitoring = true`).
   - Particles intensify and converge on the delayed player trajectory at `anchor_speed`.
   - Deals periodic damage to targets in the `"player"` group upon `DamageTick` timeout.
4. **`COOLDOWN` / `REST`** (default `1.6s`):
   - After attack duration ends, `DamageArea` is briefly deactivated while particles remain visible in a relaxed swirl, offering the player a tactical opening to counterattack with potions or move past before looping back to `TELEGRAPH`.
5. **`DISPERSED`**:
   - Triggered by explosions or disruptions.
   - `DamageArea` disabled for 0.45 ~ 0.70 seconds while particles scatter outward.
6. **`PURIFIED`**:
   - Triggered when `corruption_hp <= 0.0`.
   - Particles scatter with high disperse and fade out to alpha 0 over 0.75s, followed by `queue_free()`.

## Potion interactions

The hazard provides direct callable hooks and integrates with both `PotionEffectExecutor` and direct `PotionProjectile` hits:

| Potion / Effect | Method Called | Reaction Behavior |
| :--- | :--- | :--- |
| **Explosion / Attack Potion** (`&"attack"`, `&"lightning_meteor"`, `red_potion`) | `hit_by_explosion(impact_pt, strength)` | Disperses particles outward, pushes anchor away, and pauses `DamageArea` for ~0.5s creating a safe window. |
| **Purification Potion** (`&"purify"`, `purification_potion`) | `hit_by_purification(power)` | Decrements `corruption_hp`. Triggers visual hit flash and permanently purifies/destroys the swarm when HP reaches 0. |
| **Wind Potion** (`&"speed"`, `&"wind"`, `orange_potion`) | `hit_by_wind(dir, strength, duration)` | Blows the swarm anchor away and applies directional shader wind force over `duration` (default 0.8s). |

## Scene structure

```
BloodLeafSwarm (Node2D, blood_leaf_swarm.gd)
├─ LeafParticlesA_Back (GPUParticles2D, maple1.png, z_index = -5, background layer)
├─ LeafParticlesB_Back (GPUParticles2D, maple.png, z_index = -5, background layer)
├─ LeafParticlesA (GPUParticles2D, maple1.png, z_index = 5, foreground layer)
├─ LeafParticlesB (GPUParticles2D, maple.png, z_index = 5, foreground layer)
├─ DamageArea (Area2D, CircleShape2D radius = 60.0)
│  └─ CollisionShape2D
├─ DamageTick (Timer, wait_time = 0.35s)
├─ Telegraph (Node2D, blood_leaf_telegraph.gd, z_index = -1)
└─ AudioStreamPlayer2D
```

## Integration & Customization

- To use in any level, instantiate `res://day/levels/Crimson Vale/hazards/blood_leaf_swarm.tscn`.
- Export parameters:
  - `target`: Specific `Node2D` to chase (auto-finds `"player"` if null).
  - `telegraph_time`: Warning phase duration.
  - `attack_duration`: Active pursuit duration.
  - `tracking_delay`: Latency in seconds for historical target sampling.
  - `anchor_speed`: Maximum speed of core movement.
  - `damage` / `knockback_force`: Combat parameters.
  - `corruption_hp`: Hits required to purify.
  - `core_radius`: Radius of damage circle and telegraph ring.
