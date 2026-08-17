# Colored plant library

The source set from `De Maga et Septem Dierum Maledictione/plant` is integrated as ten production-ready `IngredientData` resources. Static records live in `shared/definitions/data/ingredients/`; their feature-specific preview and detachable artwork lives under `day/interactables/herb/herbs/<ingredient_id>/`.

## Spectrum assignment

The source folder is the authoritative color ID. Plants are distributed within the corresponding continuous alchemy band so same-color ingredients can still produce distinct weighted spectrum results:

| Color ID | Spectrum band | Imported plants |
| --- | --- | --- |
| `yellow` | `0.2857–0.4285` | Drop-Cliff Whistle-Leaf, Eyrie-Nest Seed-Ball, Wind-Cutter Rye, Egg-Climber’s Honey-Pot |
| `blue` | `0.7142–0.8571` | Chalice-Ice Spire, Tundra Snow-Whisk, Vesper Blue-Thicket |
| `purple` | `0.8571–1.0` | Dusk-Water Opuntia, Stagnant-Breeze Bell-Vine, Slumber-Marrow Geode |

Each part retains its position on the original 4096×4096 canvas. The stored texture is trimmed to its alpha boundary, while `HerbPieceData.source_rect` reconstructs its original placement on `HerbAssemblyView`. Missing whole-plant previews are composited from the supplied parts without repainting or rescaling them.

## Runtime registration

`night/alchemy/alchemy_runtime.tscn` explicitly lists all ten ingredients. `night/ui/pause_menu/pause_inventory_page.tscn` lists the same definitions for material inspection. Runtime quantities remain in the shared `PlayerData.inventory` dictionary and use the ingredient resource ID as the key.

Useful console examples:

```text
set inventory.chalice_ice_spire 10
set inventory.dusk_water_opuntia 10
set inventory.wind_cutter_rye 10
```
