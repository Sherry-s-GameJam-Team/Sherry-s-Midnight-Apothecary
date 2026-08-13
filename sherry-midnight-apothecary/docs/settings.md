# Persistent settings

`AppRoot/SettingsService` loads `user://settings.json` before the main menu is configured. Settings are independent from `user://save.json`, apply immediately, and are saved after a short debounce.

## Audio

- `Master` controls final output.
- `Music` controls all BGM.
- `DayInteriorBGM` sends to `Music` while retaining the menu-to-room spatial effects.
- `SFX` controls gameplay and ambience.
- `UI` controls button and task-completion feedback.

Persistent day and night BGM players use `PROCESS_MODE_ALWAYS`, so opening the pause menu inherits the active scene's existing track without restarting, seeking, stopping, or pausing it.

## Display and accessibility

- Window modes: windowed, borderless fullscreen, exclusive fullscreen.
- Windowed resolutions: 1280×720, 1600×900, 1920×1080.
- VSync is configurable.
- Text scales: 0.9, 1.0, 1.15, 1.3 for player-facing UI; developer/debug UI is excluded.
- Dialogue speeds: 0.055, 0.035, 0.018, or 0 seconds per character.
- Reduced motion halves the menu transition durations, disables decorative bird flight and cloud/particle drift, and replaces the pause-book slide with a short opacity transition.

Defaults are full volume, 1280×720 windowed, VSync enabled, standard text and dialogue speed, and reduced motion disabled. Invalid or missing settings fall back to these defaults.
