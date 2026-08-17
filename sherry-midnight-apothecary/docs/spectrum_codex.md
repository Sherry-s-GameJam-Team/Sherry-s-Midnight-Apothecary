# Potion Spectrum Codex (药水光谱图鉴)

`SpectrumCodexPanel` provides an interactive, data-driven codex UI for the nighttime alchemy and shop systems in *Sherry's Midnight Apothecary*. It allows players to inspect known spectral bands, function branches, and special recipes, while visualizing unlock progression.

## Key Features

1. **Dual View Modes**:
   - **Vertical Spectrum View (`SpectrumVerticalView`)**:
     - **Left Side**: Continuous vertical spectrum ribbon (`SpectrumRibbonBar`) showing smooth color transitions across all wavelength bands, dynamically synchronized to the exact vertical positions and heights of right-side band and function items.
     - **Independent Multi-Tier Indicators (独立分层指示器)**:
       - **Level 1 (波段指示器)**: Primary color pearl marker with Roman numerals, horizontally aligned with `SpectrumBandItem` header cards.
       - **Level 2 (功能分支独立指示器)**: Each function branch has its own independent diamond pip marker (`◆`) positioned at that function's real vertical position along the spectrum, connected via branch lines (`├──`).
       - Selecting either a Band or a Function lights up its specific indicator with active amber-gold halos and crimson wax pointers (`▶`) pointing directly at that item.
     - **Natural Context Scrolling & Dragging (纯滚轮上下文滚动与拖拽)**:
       - **Mouse Wheel Vertical Scrolling**: Rolling the mouse wheel scrolls the entire 3-tier codex tree (Bands $\rightarrow$ Functions $\rightarrow$ Recipes) smoothly up and down at standard 100% reading scale without scaling distortion.
       - **Left Mouse Drag (左键拖拽)** & Middle Mouse Drag: Fluid pan/scroll navigation across the canvas.
   - **Cross-table Matrix View (`SpectrumMatrixView`)**:
     - Two-dimensional grid representing Primary Functions (Rows) $\times$ Secondary Functions (Columns).
     - Dynamically generated headers and cells based on catalog data.
     - Cell states: Empty (no recipe), Undiscovered, Partially Discovered, Fully Mastered.

2. **Strict Data-Driven Architecture**:
   - UI scripts do not hardcode band names, function branches, recipe names, or matrix coordinates.
   - All data is modeled through custom Godot Resources:
     - `PotionSpectrumCatalog`: Master collection resource containing bands, functions, recipes, and matrix headers.
     - `PotionSpectrumBand`: Spectral band definition (id, color, order, spectrum_min, spectrum_max, primary_effect_name, description).
     - `PotionFunctionDefinition`: Function branch under a band (id, band_id, display_name, description, primary_tag, secondary_tag, sort_index, spectrum_position, matrix_row, matrix_col).
     - `PotionRecipeDefinition`: Special/standard recipe definition (id, function_id, display_name, description, primary_tag, secondary_tag, matrix_row, matrix_col, is_special, unlock_hint, icon).
     - `PotionSpectrumUnlockState`: Player unlock progress tracker (unlocked_function_ids, unlocked_recipe_ids, unlocked_matrix_cells).

3. **Detail Inspector Panel**:
   - Displays real-time details when selecting any Band, Function Branch, Recipe Node, or Matrix Cell.
   - Respects fog-of-war / unlock masks (locked elements display masked names "？？？", lock icons, and hints without spoiling hidden recipes).

## Public API

`SpectrumCodexPanel` provides decoupled external integration endpoints:
- `set_catalog(catalog: PotionSpectrumCatalog) -> void`
- `set_unlock_state(unlock_state: PotionSpectrumUnlockState) -> void`
- `unlock_recipe(recipe_id: StringName) -> void`
- `unlock_function(function_id: StringName) -> void`
- `set_view_mode(mode: StringName) -> void` (`&"vertical"` / `&"matrix"`)
- `refresh_view() -> void`
- `focus_recipe(recipe_id: StringName) -> void`
- `focus_function(function_id: StringName) -> void`

Signals emitted:
- `recipe_selected(recipe_id: StringName)`
- `function_selected(function_id: StringName)`
- `view_mode_changed(mode: StringName)`
- `request_close()`

## File Structure

```
res://night/ui/spectrum_codex/
  scenes/
    spectrum_codex_panel.tscn
    spectrum_vertical_view.tscn
    spectrum_matrix_view.tscn
    spectrum_band_item.tscn
    spectrum_function_item.tscn
    spectrum_recipe_node.tscn
    matrix_cell_item.tscn
    spectrum_codex_demo.tscn
  scripts/
    spectrum_codex_panel.gd
    spectrum_vertical_view.gd
    spectrum_ribbon_bar.gd
    spectrum_matrix_view.gd
    spectrum_band_item.gd
    spectrum_function_item.gd
    spectrum_recipe_node.gd
    matrix_cell_item.gd
    potion_spectrum_catalog.gd
    potion_spectrum_band.gd
    potion_function_definition.gd
    potion_recipe_definition.gd
    potion_spectrum_unlock_state.gd
    spectrum_codex_demo.gd
  resources/
    default_potion_spectrum_catalog.tres
    default_potion_spectrum_unlock_state.tres
  styles/
    spectrum_codex_theme.tres
```
