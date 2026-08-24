# Colored plant library

The source set from `De Maga et Septem Dierum Maledictione/plant` is integrated as nineteen production-ready `IngredientData` resources. Static records live in `shared/definitions/data/ingredients/`; their feature-specific preview and detachable artwork lives under `day/interactables/herb/herbs/<ingredient_id>/`.

## Spectrum assignment

The source folder is the authoritative color ID. Plants are distributed within the corresponding continuous alchemy band so same-color ingredients can still produce distinct weighted spectrum results:

| Color ID | Spectrum band | Imported plants |
| --- | --- | --- |
| `red` | `0.0–0.1428` | Mapleheart Dark Vein, Maple-Marrow Star Crystal, Waystation Lantern Fruit |
| `orange` | `0.1428–0.2857` | Sun-Etched Flower, Hanging Lantern Bell Cap, Morning-Wheel Crystal Crown |
| `yellow` | `0.2857–0.4285` | Drop-Cliff Whistle-Leaf, Eyrie-Nest Seed-Ball, Wind-Cutter Rye, Egg-Climber’s Honey-Pot |
| `cyan` | `0.5714–0.7142` | Returning-Tide Thorn Fern, Tideplate Lotus, Tide-Lantern Flower |
| `blue` | `0.7142–0.8571` | Chalice-Ice Spire, Tundra Snow-Whisk, Vesper Blue-Thicket |
| `purple` | `0.8571–1.0` | Dusk-Water Opuntia, Stagnant-Breeze Bell-Vine, Slumber-Marrow Geode |

Each part retains its position on the original 4096×4096 canvas. The stored texture is trimmed to its alpha boundary, while `HerbPieceData.source_rect` reconstructs its original placement on `HerbAssemblyView`. Missing whole-plant previews are composited from the supplied parts without repainting or rescaling them.

## Alchemy roles

The plant library supports two deliberately separate alchemy roles:

- **Chromatic processing:** detachable `HerbPieceData` parts contribute their weighted `spectrum_x`. The mixed result is evaluated against the seven-band potion spectrum, which determines the color-driven base effect.
- **Special-plant recipes:** named plants can additionally be used by an explicit special recipe or potion definition. This layer is intentionally independent of `color_id`, so a plant's unique recipe role does not overwrite the effect produced by its extracted color parts.

The eight legacy inventory-only definitions (`amber_root`, `blue_bell`, `mist_leaf`, `moon_mint`, `red_berry`, `star_lavender`, `sun_daisy`, and `violet_thistle`) were removed because they had neither production-piece data nor a runtime alchemy registration.

## Runtime registration

`night/alchemy/alchemy_runtime.tscn` explicitly lists all nineteen colored-library ingredients. `night/ui/pause_menu/pause_inventory_page.tscn` lists the same definitions for material inspection. Runtime quantities remain in the shared `PlayerData.inventory` dictionary and use the ingredient resource ID as the key.

All nineteen colored-library plants and the six initial plants have reusable `*_herb.tscn` field scenes. Story-level `LevelData.native_ingredient_ids` mirrors the explicitly authored spawn points, allowing shop progression and tests to verify that each requested color has an available daytime source.

Useful console examples:

```text
set inventory.chalice_ice_spire 10
set inventory.dusk_water_opuntia 10
set inventory.wind_cutter_rye 10
set inventory.tideplate_lotus 10
set inventory.sun_etched_flower 10
```
