# Night Production Herb Inventory

`res://night/alchemy/production/production_panel.tscn` places its herb shelf inside `HerbInventoryArt`. The artwork provides exactly twelve painted inventory cells: four columns by three rows.

`ProductionPanel` presents ingredient definitions in their explicit runtime order. A page always contains twelve controls; unused positions are transparent placeholders, so the card grid remains aligned with the artwork instead of growing a fourth row.

When more than twelve definitions are registered, the transparent hit areas over the artwork's left and right arrows call `show_previous_herb_page()` and `show_next_herb_page()`. Paging wraps around, while the center indicator is updated as `current / total`. Slot separation scales from the source artwork dimensions, preserving alignment across viewport sizes.

Refreshing inventory counts does not reset the selected page. If the current page's card identities are unchanged, the existing card controls are updated in place so an active shelf layout remains stable.

## Spectrum Preview & Effect Display (光谱色值与功效显示)

`ProductionPanel` features a top `SpectrumFrame` (`SpectrumPreview` + `SpectrumLabel`):
- Before grinding: Displays `等待加工结果`.
- Upon grinding: Previews the blended `mixed_x` color and queries `PotionSpectrumCatalog` / `PotionSpectrumUnlockState`.
  - Unlocked: Displays `当前色值 <x> · 功效：<主功效>` (e.g. `当前色值 0.050 · 功效：止血、循环`).
  - Locked: Displays `当前色值 <x> · 未知功效`.

Automated coverage lives in `res://tests/production_test.gd` and `res://tests/spectrum_codex_test.gd`.
