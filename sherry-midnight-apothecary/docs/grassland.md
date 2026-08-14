# Grassland

The daytime Grassland level is configured by day/levels/grassland/grass.tscn and exposed through day/levels/grassland/grassland_level.tres.

Its purification completion presentation uses the shared es://shared/ui/task_complete/task_complete_ui.tscn scene. This avoids loading the legacy day-specific UI duplicate and keeps the level's completion UI reusable across runtimes.
