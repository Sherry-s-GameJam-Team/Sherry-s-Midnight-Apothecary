# Sound effect sources

All sound effects in `audio/sfx/` are released under Creative Commons Zero
(CC0). Attribution is not required, but the source details are retained here
for provenance and future replacement work.

| Project file | Original file | Creator | Source | License | Use |
| --- | --- | --- | --- | --- | --- |
| `footsteps.ogg` | `steps.ogg` | Delta12 Studio | [Rpg Sound Effect Pack](https://opengameart.org/content/rpg-sound-effect-pack) | CC0 | Character walk/run cadence |
| `spell_cast.ogg` | `magical_1.ogg` | JaggedStone | [Magic Spell SFX](https://opengameart.org/content/magic-spell-sfx) | CC0 | Potion casting wind-up |
| `spell_release.ogg` | `magical_4.ogg` | JaggedStone | [Magic Spell SFX](https://opengameart.org/content/magic-spell-sfx) | CC0 | Potion release |
| `door_open.wav` | `door_open.wav` | laleksic | [Various Sound Effects](https://opengameart.org/content/various-sound-effects) | CC0 | Door opening |
| `door_close.wav` | `door_close.wav` | laleksic | [Various Sound Effects](https://opengameart.org/content/various-sound-effects) | CC0 | Door closing |
| `ui_press.ogg` | `item.ogg` | Delta12 Studio | [Rpg Sound Effect Pack](https://opengameart.org/content/rpg-sound-effect-pack) | CC0 | Enabled UI button press |
| `ui_hover.ogg` | `cancel.ogg` | Delta12 Studio | [Rpg Sound Effect Pack](https://opengameart.org/content/rpg-sound-effect-pack) | CC0 | Enabled UI button hover |

License deed: <https://creativecommons.org/publicdomain/zero/1.0/>

## Runtime mapping

- `SoundManager` is an autoload so transition sounds survive scene changes.
- UI feedback is attached automatically to every `BaseButton`, including
  buttons created after a scene has loaded.
- Footsteps use movement-aware cadence and subtle pitch variation.
- Potion casting has separate wind-up and release cues.
- Door portals play an open cue followed by a close cue during level travel.
