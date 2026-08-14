# Grassland

The daytime Grassland level is configured by `day/levels/grassland/grass.tscn` and exposed through `day/levels/grassland/grassland_level.tres`.

Its purification completion presentation uses the shared `res://shared/ui/task_complete/task_complete_ui.tscn` scene. The corruption state applies the corrupted texture to every `Sprite2D` named `GrassLoop*`, including future loop sprites added to the scene.
