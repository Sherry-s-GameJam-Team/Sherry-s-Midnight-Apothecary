# Herb harvesting

`HerbInteractable` provides the day exploration pickup interaction. It resolves each plant's `IngredientData.preview_texture`, so the field sprite exactly matches the material used by the alchemy inventory and production board. Press `E` while in range to add one item to `PlayerData.inventory`.

Each `HerbSpawnPoint` owns one explicit `herb_scene` assignment. The director instantiates that exact scene and never rolls, rotates, or substitutes an ingredient ID. A collected point stays empty for the rest of that day, including after re-entering the level.

Grassland's fixed assignments are `P01/P07` Herdsman's Loaf-Bush, `P02/P08` Stardust Puffy-Lion, `P03/P09` Grail-Lily, `P04/P10` Dew-Flask Herb, `P05` Old Man's Noose, and `P06` Praise-Star Maple. Forest's four test points are fixed to Stardust Puffy-Lion, Grail-Lily, Dew-Flask Herb, and Old Man's Noose in `P01`–`P04` order.

The six formal Grassland plants each have a reusable plant scene under `res://day/interactables/herb/herbs/<ingredient_id>/`. A new authored point should use one of these scenes (or another scene rooted in `HerbInteractable`) rather than assigning an ID through code.

The director removes all field pickups whenever Grassland is corrupted. They respawn only after the environment becomes normal. The system is reusable: another normal/corrupted `DayLevelEnvironment` can add authored `HerbSpawnPoint` children under `HerbSpawns` and a `HerbSpawnDirector` to use the same collection-persistence rules.
