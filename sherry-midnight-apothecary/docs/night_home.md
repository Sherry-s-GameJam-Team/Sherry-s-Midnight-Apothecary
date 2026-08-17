# Night Home & Luca Interaction

The nighttime Home scene is configured by `night/levels/home/home.tscn` and managed by `NightRuntime`.

## Luca NPC & First Night Onboarding Flow

On Day 1 night (or initial entry before completion), Luca is present in the shop (`night/levels/home/luca_night_npc.tscn`):

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

## Night Bedroom Barrier Check (Ending Night Business)

When the player approaches the left bedroom barrier (`BedroomEntrance`) at night and triggers it (`按[E]进入卧室区域`):
1. **Business State Check**:
   - Checks whether the shop has operated tonight (`has_operated`), how many customers have been completed (`completed_customers`), and the number of customers currently waiting at the counter (`remaining_customers = n`).
2. **Interactive Confirmation Dialogue**:
   - Launches `night/levels/home/night_bedroom_barrier.dialogue` via `ApothecaryDialogueBalloon`.
   - Displays whether the shop has been operated and dynamically shows the remaining customer count `n`.
   - Prompts the player to confirm whether to end business (`是否结束营业`).
3. **Barrier Opening & Rest Flow**:
   - If the player chooses **结束营业**: `NightBedroomBarrier` invokes `HomeCameraDirector.open_barrier()`, dissolving the barrier visual and unlocking physical passage into the bedroom area.
   - If the player chooses **继续营业 / 先去营业 / 再等等**: the barrier remains locked, allowing the player to continue brewing and serving customers.

## Automated Verification

Tests for Luca's night interaction, NightHome scene, and the Night Bedroom Barrier are located in:
- `res://tests/night_luca_interaction_test.gd`
- `res://tests/night_home_scene_test.gd`
- `res://tests/night_bedroom_barrier_test.gd`
