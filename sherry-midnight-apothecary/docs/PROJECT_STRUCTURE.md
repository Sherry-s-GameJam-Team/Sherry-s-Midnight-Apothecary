# Project structure

This directory documents the Godot project rooted beside `project.godot`.

- `app/` owns `AppRoot`, `GameFlow`, and the persistent settings service. A new game starts on internal day 0 at the first daily-level rotation entry; completing its night advances to day 1.
- 剧情文档中的“第 N 天”默认对应内部天数 `N`：因此“第二天”固定为 `day == 2`。内部 day 0 是开场/教程槽位，不按剧情天数编号。
- `audio/` owns shared BGM, SFX, and `SoundManager`.
- `menu/`, `day/`, and `night/` own their runtime presentation and gameplay.
- `shared/` owns explicitly shared data and reusable systems.
- `tests/` owns automated verification; `tmp/` is scratch output only.
- `docs/` owns maintained feature documentation.

Game files must use `res://` paths rooted here. The similarly named legacy workspace directory is not a production project.
