# Night Home & Luca Interaction

The nighttime Home scene is configured by `night/levels/home/home.tscn` and managed by `NightRuntime`.

## Day-specific night NPCs

Night Home calls `configure_for_day(day)` whenever the runtime is configured and whenever the player returns from the bedroom, so NPC visibility and interaction are rebuilt from the current internal day.

- `day == 0`: only `LucaNightNPC` is active. Its existing onboarding and repeat dialogue remain the tutorial-night content described below.
- `day == 1`: `LucaNightNPC` is hidden and `issue/Day1/EnzuoNightNPC` is active in the bedroom rest area. Enzuo loops the eight authored `characters/enzuo/idle/idle_00..07.png` frames; approaching him shows “按[E]与恩佐交谈”. The E-key dialogue uses `enzuo_day_one.dialogue`, retains the supplied question menu, and resolves Enzuo's dialogue portrait from `res://characters/enzuo/standee.png`.
- Other days: both of these day-specific NPC nodes are hidden until their own content is authored.

## Luca NPC & Day 0 Onboarding Flow

On internal Day 0 night, Luca is present in the shop (`night/levels/home/luca_night_npc.tscn`):

1. **Player Interaction**:
   - Player approaches Luca and presses `E` to interact.
   - Triggers Part 1 dialogue (`~ intro_part1` in `night/levels/home/luca_night.dialogue`), locking player input.
2. **Herb Reward & Hint UI**:
   - After Part 1 dialogue completes, TopHintUI displays `已收集露水水滴草*2`.
   - Adds 2x `dew_flask_herb` to `PlayerData.inventory` (guarded by `night_luca_dew_flask_given` to prevent duplication).
3. **Follow-up Dialogue**:
   - After a brief delay (1.6s), Part 2 dialogue (`~ intro_part2`) automatically triggers.
4. **Alchemy Guidance**:
   - After Part 2 dialogue finishes, `night_luca_intro_completed` is stored in `PlayerData.tutorial_flags`.
   - TopHintUI guides the player towards the alchemy station: “前往左侧制药台（坩埚），按[E]开启炼药界面”.
   - The alchemy station (`Equip` node) is highlighted.
   - When the player interacts with `Equip` or opens the alchemy runtime, the guidance is cleared.
5. **Subsequent Interactions**:
   - Interacting with Luca after completing the intro triggers repeat dialogue (`~ repeat`).

## Day 0 Alchemy Tutorial Guide (炼药新手引导)

When entering `AlchemyRuntime` on Day 0 before completing the tutorial (`day0_alchemy_tutorial_completed`), the `AlchemyTutorialGuide` overlay activates:

1. **Step 1 (Open Codex)**: Animated gold arrow points upward to `PullHandle` at the top with instructions: *“点击上方光谱把手，查阅【湛蓝净化药水】配方与光谱波段特性”*.
2. **Step 2 (Inspect Spectrum)**: When codex slides down, prompts that blue band ($0.71 \sim 0.86$) governs purification & dispel, instructing player to press `[ESC]` or click close after reading.
3. **Step 3 (To Production)**: Arrow points to `ToProductionArrow` (top-right yellow arrow) to switch to the processing station.
4. **Step 4 (Take Herb & Dragging)**: Points to `dew_flask_herb` on `HerbGrid` to drag onto `ProcessBoard`, noting: *“按住鼠标左键长按可多零件范围吸附”*. If player picks another herb, it is rejected with a warning to choose `露水水囊草`.
5. **Step 5 (Separate Herb)**: Points to `SeparateButton` to separate the plant into foliage and the blue water drop.
6. **Step 6 (Grind Zone Drag)**: Points from the blue water droplet to the right-side `研磨区` (Grind Zone).
7. **Step 7 (Grind Powder)**: Points to `GrindButton` to crush the component into blue powder.
8. **Step 8 (Discard Leaves to Waste)**: Points to remaining green foliage pieces with trajectory towards the left discard bin (`waste_zone`), instructing: *“装粉前需保持案板整洁，请将除了水珠以外的多余绿叶部位拖入左侧弃置箱”*.
9. **Step 9 (Pack Powder)**: Points to `PackPowderButton` to pack the powder into the unified powder shelf.
10. **Step 10 (Back to Brewing)**: Points to `BackToBrewingArrow` (top-left) to slide back to the cauldron screen.
11. **Step 11 (Feed Cauldron)**: Points from `UnifiedPowderShelf` to `CauldronDropZone` with trajectory line.
12. **Step 12 (Start Brew)**: Points to `BrewButton` to commence heating.
13. **Step 13 (Bellows & Heat Control)**: Points to `BellowsControl`, clarifying: *“抽拉风箱提升温度并推进蒸馏（点击鼠标左键 或 按【空格键】）”*.
14. **Step 14 (Confirm Bottling)**: Points to `BottlingPanel` confirm button. Upon confirmation, records `day0_alchemy_tutorial_completed` into `PlayerData.tutorial_flags` and deactivates the guide.

## Night Bedroom Barrier Check (Ending Night Business)

When the player approaches the left bedroom barrier (`BedroomEntrance`) at night and triggers it (`按[E]进入卧室区域`):
0. **Immediate Input Binding**:
   - `NightBedroomBarrier` binds `HomeCameraDirector.entrance_handler` during `_ready()`, so the entrance cannot bypass the business-state check during the first rendered frame.
1. **Business State Check**:
   - Checks whether the shop has operated tonight (`has_operated`), how many customers have been completed (`completed_customers`), and the number of customers currently waiting at the counter (`remaining_customers = n`).
2. **Interactive Confirmation Dialogue**:
   - Launches `night/levels/home/night_bedroom_barrier.dialogue` via `ApothecaryDialogueBalloon`.
   - Displays whether the shop has been operated and dynamically shows the remaining customer count `n`.
   - Prompts the player to confirm whether to end business (`是否结束营业`).
3. **Barrier Opening & Rest Flow**:
   - If the player chooses **结束营业**: `NightBedroomBarrier` invokes `HomeCameraDirector.open_barrier()`, dissolving the barrier visual and unlocking physical passage into the bedroom area.
   - If the player chooses **继续营业 / 先去营业 / 再等等**: the barrier remains locked, allowing the player to continue brewing and serving customers.

## Customer Patience & Rejection Rules

1. **Immediate Departure & Patience Loss**:
   - Refusing a customer immediately removes them from the current night's queue (`顾客离场`).
   - Deducts **25%** patience (`REFUSAL_PATIENCE_LOSS = 25.0`), persistent across days.
2. **Exponential Reputation Penalty**:
   - Each refusal of a customer incurs a store reputation penalty of $2^n$ (`int(pow(2.0, refusal_count))`), where $n$ is the cumulative number of times this customer has been refused.
3. **Accurate Medication Recovery**:
   - Precise/perfect potion matching (`Outcome.PERFECT`, `Outcome.SPECIAL`, or score $\ge 80$) restores customer patience by **+25%** (capped at 100%).
4. **Final Refusal Warning & Permanent Loss**:
   - When a customer's current patience is $\le 25\%$ (the next refusal would reduce patience to 0%), clicking reject triggers a `RejectConfirmDialog` modal warning: refusing again will permanently lose this customer.
   - Once a customer's patience reaches **0%**, they are marked `permanently_lost` and will never visit the apothecary again.

## Night Exit Transformer

The night scene retains the `Transsformer` artwork at the same room position as the daytime home, but disables the node's processing, monitoring, interaction script, and collision. It is presentation-only at night: approaching or pressing `E` produces no hint, message, or map transition.

## Current Queue Sizes

- Store reputation `>= 70`: up to 8 eligible customers.
- Store reputation `40–69`: up to 2 customers, without premium customers.
- Store reputation `< 40`: up to 1 low-tier customer.

These values replace the prototype test expectation of three customers at high reputation.

## Automated Verification

Tests for Luca's night interaction, NightHome scene, shop operations, and the Night Bedroom Barrier are located in:
- `res://tests/night_luca_interaction_test.gd`
- `res://tests/night_home_scene_test.gd`
- `res://tests/night_bedroom_barrier_test.gd`
- `res://tests/business_shop_test.gd`
