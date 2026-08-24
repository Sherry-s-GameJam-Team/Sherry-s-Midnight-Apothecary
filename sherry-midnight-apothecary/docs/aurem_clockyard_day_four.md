# Aurem Clockyard — Day 4 night patrol

`World/NPCs/Clockmaker` becomes the Night Patrol Cleaner No. 7 only when
`DayRuntime.day == 4`. Its local controller provides the `[E]` dialogue prompt,
random horizontal patrol targets inside 300px of its placed x-coordinate, and
a high-frequency visual vibration. The full branching narrative is in
`res://day/levels/Aurem Clockyard/clockmaker_day_four.dialogue`; it registers
`robot.png` as the cleaner's Dialogue Manager portrait at runtime.

The full first-meeting dialogue and its investigation choices are recorded by
the `aurem_clockmaker_intro_complete` event flag. Later E-key interactions use
the concise `repeat` dialogue title instead.

The exterior `TowerPortal` transitions through the registered
`aurem_clockyard_inside` LevelData to `inside.tscn` at its `tower_inner`
entry point.
