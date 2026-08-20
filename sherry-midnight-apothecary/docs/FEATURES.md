# Feature documentation

- [Persistent settings](settings.md): audio categories, display modes, text and dialogue accessibility, reduced motion, and pause behavior.

- [Grassland](grassland.md): daytime grassland scene, purification tutorial, and shared completion UI.

- [Shimmering Cliff](cliff.md): resonance-wave warnings, procedural avalanche zones, unified hazard feedback, and default-entry respawn protection.

- [Herb harvesting](herb_harvesting.md): normal-state daily field pickup refreshes for alchemy ingredients.

- [Colored plant library](colored_plant_library.md): thirteen yellow, cyan, blue, and purple production plants with alpha-trimmed detachable artwork and explicit spectrum assignments.

- [Magic Map Switch](../day/interactables/map_switch/README.md): Home Transformer route-anchor alignment and first-use navigation tutorial.

- [Day interactables](../day/interactables/README.md): reusable daytime interaction helpers, including proximity hint areas and the controller/controlled system.

- [Scene title card](scene_title_card.md): per-level `DisasterName` and `NormalDescription` subtitle data, daily presentation rules, and title replay behavior.

- [Potion direct hits](potion_hits.md): collision-box impact receiver contract and splash-effect integration.

- [Day health and recovery](day_health.md): global HP, healing effects, hazard damage, same-day rollback, and Bedroom revival.

- [Day character switching](CHARACTER_SWITCHING.md): remote scene-assembly contract for Sherry/Luca node paths, controls, camera ownership, and validation.

- [Forest level](../day/levels/forest/docs/FOREST_LEVEL.md): exterior waterwheel progression, tree-gate handoff to the standalone interior level, restoration flow, and Crown handoff.

- [Forest interior level](../day/levels/forest/docs/FOREST_INTERIOR_LEVEL.md): standalone tree-interior dual-character level — control rooms, spray purification, lifts, sluice gate, and the completed Crown Boss handoff.

- [Forest crown boss level](../day/levels/forest/docs/FOREST_CROWN_LEVEL.md): standalone Seraph boss encounter — 3-phase corruption mechanics, halo/core weakpoints, feather storm, procedural blood rain, and radial purification VFX.

- [Golden cliff](golden_cliff.md): standalone `烁金横崖` day level — balance-stone calibration, floating/debris hazards, portal repair, embedded standalone DeveloperConsole, embedded PauseMenu (B-key backpack, ESC menu), and `LEVELS` registration for the global SceneTitleCard.

- [Night home & Luca interaction](night_home.md): nighttime apothecary interior, Luca intro dialogue sequence, herb rewards, hintUI feedback, alchemy guidance, and bedroom barrier business check with remaining customer confirmation.

- [Lake bottom](lake_bottom.md): exposed lakebed day level — three spring valves, Tide Eye boss purification, standard Sherry player controller, embedded developer console & pause menu, and LevelData registration.

- [Potion Spectrum Codex](spectrum_codex.md): interactive, data-driven codex UI featuring vertical spectrum zoom/pan LOD view, cross-table primary x secondary function matrix view, and unlock progress tracking.

- [Potion Bottling Workshop](potion_bottling.md): nighttime alchemy bottling UI with arrow-based bottle style switcher, smart default naming, primary/secondary effect breakdown, and medieval parchment styling.

- [Night production herb inventory](production_processing.md): artwork-aligned 4 × 3 herb shelf with responsive slot spacing and paged navigation.
- [Dialogue Character Portraits](dialogue_portrait.md): 3-slot (left, center, right) character portrait presentation, Dialogue Manager tag/command syntax integration, expression cross-fading, focus dimming, and entrance/reaction animations.
- [Crimson Vale](crimson_vale.md): daytime Crimson Vale level — 3-layer parallax background, village buildings and maple resin props, Danxin Gate restoration state machine, player controller integration, and LevelData registration.
- [Blood Leaf Swarm](blood_leaf_swarm.md): reusable delayed-tracking maple leaf swarm hazard, GPUParticles2D particle shader with 3D fluttering & swirling, and wind/explosion/purification potion interactions.
- [Crimson Vale Challenge](crimson_vale_challenge.md): horizontal platforming gauntlet with broken cliff jumps, village rooftop leaps, Blood Leaf Swarm hazards, and ForegroundShelter stealth mask mechanics.
- [Alkeon Boss Encounter](alkeon_boss.md): 3-phase Blood Leaf Hunt King boss battle — 3-zone arena, wind chime acoustic/visual telegraphs, Blood Leaf Surge hazards, Wind Potion headwind counterplay, and Danxin Gate to Orem Clocktower transition.
- [Aurem Clockyard](aurem_clockyard.md): daytime Aurem Clockyard level — 3-layer parallax background (FS, MS, CS), Golden Farm normal/corrupted state machine, Great Clocktower exterior and inner core chamber, one-way drop-through platforms, Clockmaker NPC interaction, and LevelData registration.
- [Vespervale Garden](vespervale_garden.md): daytime Vespervale Garden level — non-repeating layered background (FS, Mid, GardenAtmosphere), Real/Dream Garden state switching, sleeping NPC interactions, Sherry player controller, camera bounds, and LevelData registration.
- [Vespervale Inner Ward Corridor](vespervale_inner.md): daytime Vespervale Inner Dream Hospital level — 2D dual-layer corridor platformer, 1-second chime/screen telegraphs, 6-10s rhythmic Dream Shift state machine, 5 progression zones, window/door bullet patterns, dream bridges, rolling stretchers, creeping mist wall, Dream Marrow Node activation, and LevelData registration.
- [Vespervale Dream Grasp Hands](vespervale_dream_grasp.md): 5-state predictive enemy mechanic (`LURK` -> `TRACK` -> `LOCK` -> `ERUPT` -> `RETRACT`), 24-frame animation, bed safe zones with ward auras, 3-tier hunting escalation, character-switch baiting, and upper/lower platform detection.
- [Vespervale Runner](vespervale_runner.md): 2-minute dual-character parkour auto-runner — Sherry on lower track (Space key jump), Luca on upper track (W key jump), constant rightward camera scroll, phased obstacle track, finish line deceleration, and E-key exit portal.
- [Developer Console](developer_console.md): in-game debug console with dynamic scene switching, numbered level indices (1-17), Chinese/English alias resolution, inventory/stat mutations, and boss test jump.
