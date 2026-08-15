# Herb harvesting

`HerbInteractable` provides the day exploration pickup interaction. It resolves each plant's `IngredientData.preview_texture`, so the field sprite exactly matches the material used by the alchemy inventory and production board. Press `E` while in range to add one item to `PlayerData.inventory`.

Grassland owns authored `HerbSpawns` markers and a `HerbSpawnDirector`. In the normal state it creates pickups from the six formal alchemy plants: Herdsman's Loaf-Bush, Stardust Puffy-Lion, Grail-Lily, Dew-Flask Herb, Old Man's Noose, and Praise-Star Maple. `P10` is always a Dew-Flask Herb; every other marker rotates the remaining five plants in a deterministic daily order. A collected marker stays empty for the rest of that day, including after re-entering the level.

The director removes all field pickups whenever Grassland is corrupted. They respawn only after the environment becomes normal. The system is reusable: another normal/corrupted `DayLevelEnvironment` can add `HerbSpawns` markers and `HerbSpawnDirector` to use the same daily rules.
