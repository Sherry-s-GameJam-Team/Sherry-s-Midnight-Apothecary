# Potion Bottling Workshop (药水装瓶与分装工坊)

`BottlingPanel` (`res://night/alchemy/bottling_panel.tscn`) handles the post-brewing bottling stage in the nighttime alchemy system. After heat distillation completes, players choose an appropriate bottle shape, inspect the quality and primary/secondary effects, and assign or customize the potion's title.

## Key Features

1. **Arrow-Based Bottle Style Switcher**:
   - Replaces static button rows with intuitive left/right arrow buttons (`◀` / `▶`) framing the bottle pedestal preview.
   - Cycles through all unlocked bottle aesthetics:
     - `health` (经典圆瓶)
     - `heart` (爱心魔瓶)
     - `ice` (棱晶冰瓶)
     - `moon` (新月圣瓶)
     - `sleep` (平底长颈瓶)
   - Dynamic style label displays the active bottle shape and progress (e.g. `“爱心魔瓶” (2/5)`).

2. **Automatic Default Potion Naming**:
   - Generates contextual default names derived from the potion's primary effect, secondary effect modifications, and base potion characteristics (e.g. `生机回春药水`, `轻灵·生机回春药水`, `狂热力量药水`).
   - LineEdit is pre-filled with the smart default name, allowing players to either confirm immediately or customize with up to 12-16 characters.

3. **Primary & Secondary Effect Breakdown**:
   - **Quality**: Formatted tier name (粗劣 / 普通 / 良好 / 卓越 / 完美) and numerical quality multiplier.
   - **Primary Effect (主效果)**: Description of the main active effect (e.g. `恢复生命与伤势`, `强化攻击`, `生成防护屏障`).
   - **Secondary Effect (副效果)**: Description and multiplier when secondary effects are preserved during heating (e.g. `提升行动速度 (×1.25)`), or graceful fallback when no secondary effect is present.

4. **Medieval Parchment Aesthetic**:
   - Themed with warm aged vellum tones (`#f6f0e2`), dark walnut leather framing (`#5c3e21`), sepia iron-gall ink headers, and a sealing-wax crimson confirmation button (`✦ 确认装瓶并入库 ✦`).
   - Supports auto-stored black potions produced from failed brews with dedicated failure state notices.

## Public API & Signals

- `open_for(source_potion: PotionData, source_instance: Dictionary) -> void`
- `show_auto_stored(source_potion: PotionData, source_instance: Dictionary) -> void`
- Signal: `confirmed(style_id: StringName, custom_name: String)`
