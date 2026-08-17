# Night Production Herb Inventory

`res://night/alchemy/production/production_panel.tscn` places its herb shelf inside `HerbInventoryArt`. The artwork provides exactly twelve painted inventory cells: four columns by three rows.

`ProductionPanel` presents ingredient definitions in their explicit runtime order. A page always contains twelve controls; unused positions are transparent placeholders, so the card grid remains aligned with the artwork instead of growing a fourth row.

When more than twelve definitions are registered, the transparent hit areas over the artwork's left and right arrows call `show_previous_herb_page()` and `show_next_herb_page()`. Paging wraps around, while the center indicator is updated as `current / total`. Slot separation scales from the source artwork dimensions, preserving alignment across viewport sizes.

Refreshing inventory counts does not reset the selected page. If the current page's card identities are unchanged, the existing card controls are updated in place so an active shelf layout remains stable.

Automated coverage lives in `res://tests/production_test.gd` and verifies the 4 × 3 cap, page indicator, arrow wrap behavior, and empty slots on a partial final page.
