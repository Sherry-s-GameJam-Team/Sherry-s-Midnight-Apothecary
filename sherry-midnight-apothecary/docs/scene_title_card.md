# Scene title card

The daytime `SceneTitleCard` displays the day number, the current level's `display_name`, and one subtitle line below the main title.

The subtitle is selected by `LevelData.title_subtitle_for_day(day)`:

- On a configured disaster day, it uses `disaster_name` (`DisasterName`).
- On a normal day, it uses `normal_description` (`NormalDescription`).

Each `day/**/**/*_level.tres` resource provides its own `normal_description`. Home and Bedroom keep `show_title_card = false`, so their descriptions are not presented.

Automatic presentation is tracked in `PlayerData.tutorial_flags` with the key `scene_title_seen:<day>:<level_id>`. The developer console's `title` command replays the current title manually.
