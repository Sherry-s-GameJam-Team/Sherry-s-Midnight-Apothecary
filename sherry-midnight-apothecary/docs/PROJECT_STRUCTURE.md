# Project structure

This directory documents the Godot project rooted beside `project.godot`.

- `app/` owns `AppRoot`, `GameFlow`, and the persistent settings service.
- `audio/` owns shared BGM, SFX, and `SoundManager`.
- `menu/`, `day/`, and `night/` own their runtime presentation and gameplay.
- `shared/` owns explicitly shared data and reusable systems.
- `tests/` owns automated verification; `tmp/` is scratch output only.
- `docs/` owns maintained feature documentation.

Game files must use `res://` paths rooted here. The similarly named legacy workspace directory is not a production project.
