# Scene title card

The daytime `SceneTitleCard` displays the day number (including the game's opening day 0), the current level's `display_name`, and one subtitle line below the main title.

The subtitle is selected from the current `DayLevelEnvironment` state through `LevelData.title_subtitle_for_environment_state(corrupted)`:

- In normal state, it uses `normal_description` (`NormalDescription`).
- In corrupted state, it uses `corrupted_description` (`CorruptedDescription`).

Every daytime environment inherits `set_corrupted(corrupted)` and `is_corrupted()` from `DayLevelEnvironment`. Levels can override `set_corrupted()` to switch visuals; Grassland does so for its sky, horizon, and grass textures. `disaster_name` and `disaster_days` remain available for legacy day-based title data.

Each `day/**/**/*_level.tres` resource provides its own `normal_description`. Home and Bedroom keep `show_title_card = false`, so their descriptions are not presented.

Automatic presentation is tracked in `PlayerData.tutorial_flags` with the key `scene_title_seen:<day>:<level_id>`. The developer console's `title` command replays the current title manually.
