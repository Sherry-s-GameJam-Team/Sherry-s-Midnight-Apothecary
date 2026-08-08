# Codex migration prompt

Copy the prompt below into Codex while its working directory is the root of the target Godot 4.6 project.

---

You are modifying an existing Godot 4.6 project. Integrate the supplied "Magic Map Switch" prototype into the existing game without breaking current player control, day/night flow, potion throwing, save data, or scene transitions.

SOURCE PACKAGE
- The prototype folder contains:
  - assets/device/transsformer.png
  - assets/device/wheel.png
  - assets/device/switch.png
  - scripts/map_switch_controller.gd
  - scripts/map_canvas.gd
  - scripts/lever_confirm.gd
  - scripts/crosshair.gd
  - scripts/magic_overlay.gd
  - shaders/dial_to_map.gdshader
  - README.md
- Read README.md before editing anything.

GOAL
Create a reusable map-switch interaction for Sherry's Midnight Apothecary. The main machine uses transsformer.png. Its upper circular aperture starts with wheel.png. When activated, the rune wheel magically dissolves into a live draggable map. The map is visible only through the circular aperture. The selection cursor remains fixed at the exact circle center while the map moves beneath it. Map nodes become magnetically attracted near the center. Releasing near the center snaps the nearest node into the cursor and shows destination details. The player then drags switch.png downward to confirm.

CRITICAL CURRENT BEHAVIOR
Do NOT implement a real scene change in this task. Confirmation must emit a signal only:
    travel_requested(destination_id: StringName, destination_data: Dictionary)
The real scene switch will be added later through the project's GameFlow/SceneRouter. Do not call get_tree().change_scene_to_file(), change_scene_to_packed(), reload_current_scene(), or any equivalent travel API from the map-switch component.

INTEGRATION PLAN
1. Inspect the target project tree first. Locate:
   - the common player controller currently used by Town/RainTree/Lake;
   - the current interaction / input-lock pattern;
   - GameFlow or the nearest equivalent scene-flow owner;
   - GlobalUI or another suitable modal UI parent.
2. Create a dedicated folder, preferably:
   res://day/interactables/map_switch/
   Keep textures, shader, scripts, scene, and optional data subfolders together.
3. Copy the prototype assets and code into that folder and repair all preload/resource paths.
4. Convert the prototype into a reusable authored scene if appropriate:
   MapSwitchInteraction (Control)
   - DimBackground
   - DeviceStage
     - InstrumentSprite
     - MapViewport (SubViewport)
       - MagicMapCanvas
     - CircularDisplay (Sprite2D with dial_to_map shader)
     - MagicOverlay
     - FixedSelectionCursor
   - DestinationPanel
   - TravelConfirmLever
   - CloseButton if the target interaction framework normally provides one
5. Preserve these functional constants unless alignment testing shows the migrated texture is different:
   DEVICE_DISPLAY_CENTER = Vector2(543, 337) in the 1086x1448 source texture
   DEVICE_DISPLAY_DIAMETER = 424
   MAP_VIEWPORT_SIZE = 512x512
   MAGNET_RADIUS about 94
   SNAP_RADIUS about 108
6. Keep the map cursor fixed. Never drag the cursor. The dragged object is the map/chart itself.
7. Use the SubViewport + circular shader approach. Do not permanently crop map textures; the map must be able to pan under the aperture.
8. Preserve the activation effect: wheel.png -> live map through a cyan/violet magical dissolve, plus short ring/spark overlay.
9. Preserve progressive magnetic attraction. It must feel stronger as a node nears the center rather than instantly teleporting from the outer threshold.
10. The right detail panel updates only after a destination is successfully snapped.
11. The confirm lever is disabled until a destination is snapped. A downward pull crossing about 82% emits travel_requested exactly once for that pull, then springs back.
12. Add an interaction lock while this UI is open:
    - player horizontal movement disabled;
    - potion aiming/throw input disabled;
    - world interaction input disabled except this modal;
    - restore previous input state when closed.
    Reuse the project's existing lock mechanism if one exists. Do not invent a second competing global input manager.
13. Do not use an event bus unless the existing project already uses one. Prefer a direct signal connection from MapSwitchInteraction to its owner/GameFlow.
14. Destination data should be separated from rendering. If the project already has a location registry, adapt to it. Otherwise create a small Resource or typed data script containing:
    id, display_name, subtitle, map_pos, danger, distance_text, environment, description
    Do not add scene_path yet unless a pre-existing scene registry already requires it.
15. Add a temporary integration receiver in the parent/GameFlow that logs:
    [MapSwitch] travel requested: <destination_id>
    and performs no scene change.
16. Make the component keyboard-safe enough to close using the project's normal cancel action if such a modal pattern exists, but do not replace the mouse-centered interaction.
17. Keep texture filtering consistent with the target project's hand-drawn 2D art settings. Do not globally change import defaults unless necessary.

EXPECTED PLAYER FLOW
A. Player interacts with the machine in the world.
B. World controls lock and MapSwitchInteraction opens.
C. Circular display shows the supplied rune wheel.
D. activate() runs; magical dissolve reveals the map.
E. Player holds LMB in the circle and drags the map.
F. A node entering the magnetic zone is gently attracted to center.
G. On release inside snap radius, the map eases so that node sits exactly under the fixed center cursor.
H. Destination details appear at right.
I. Lever enables.
J. Player drags lever downward past threshold.
K. Component emits travel_requested(id, data).
L. Temporary receiver logs the signal only. Scene remains unchanged.

ACCEPTANCE CHECKS
- Project opens in Godot 4.6 with no parser errors.
- Existing Town/RainTree/Lake character controller still works outside the modal.
- Opening the modal prevents accidental player movement/potion throws.
- Circular display starts as wheel.png.
- Activation visually transitions to the live map.
- No rectangular map pixels are visible outside the circular aperture.
- Cursor is visually fixed at circle center while panning.
- Nodes move with the map.
- Magnetic attraction is visible/feelable close to center.
- Snap aligns the chosen node exactly to the cursor.
- Destination detail panel changes after snap.
- Lever cannot confirm before selection.
- Lever confirmation emits one travel_requested signal per completed pull.
- There is no actual scene switch anywhere in the new component.
- Closing the UI restores the game's previous input state.

DOCUMENTATION
Create or update:
res://day/interactables/map_switch/README.md
Include:
- scene structure;
- public methods/signals;
- destination data format;
- exact file responsible for future travel hookup;
- a clearly marked section named "FUTURE: REAL SCENE TRAVEL" showing where GameFlow should later resolve destination_id and start the existing transition system;
- tuning constants for display center/diameter, magnetic radius, snap radius, activation duration, and lever threshold.

Before finishing, search the modified files for these forbidden calls and confirm none were added by this feature:
- change_scene_to_file
- change_scene_to_packed
- reload_current_scene

Then report:
1. files added/modified;
2. integration point used for the input lock;
3. where travel_requested is connected;
4. exact location documented for the future real scene-switch implementation;
5. any assumptions that still require editor-side visual alignment.

---
