# Camera System

> **Status**: In Design
> **Author**: Design session + systems-designer
> **Last Updated**: 2026-03-31
> **Implements Pillar**: Every Eat Feels Good / Web-Native Delight

## Overview

The Camera System places a perspective `Camera3D` at the position defined by
the level's `CameraAnchor` node and adjusts its height as the hole grows. At
level start, Camera System reads the `CameraAnchor` transform as the base
position. As the hole levels up, the camera smoothly interpolates upward using
a per-hole-level height multiplier array — pulling back to keep the growing void
in frame without changing the camera's XZ position, rotation, or pitch. The
multiplier array is a global camera config resource tuned by level designers
alongside the growth curve. Camera System owns the camera's field of view,
near/far clip planes, height multipliers, and the fallback framing used if a
level scene has no `CameraAnchor`.

## Player Fantasy

The camera is the frame of the painting. A well-placed camera makes the diorama
feel like a curated miniature world — everything the player needs is visible,
the hole is always readable, and the perspective gives depth to the cascade
collapse without obscuring it. The player should never need to wonder where an
object is or feel that the camera is fighting them. Done right, the camera is
invisible — the player thinks about the objects, not the viewpoint. Done wrong
— a cropped diorama where objects spawn off-screen, or a flat overhead angle
that kills the 3D depth of a tumbling pile — and the scene loses its toy-world
charm.

## Detailed Design

### Camera Setup

| Property | Value | Rationale |
|----------|-------|-----------|
| Projection | Perspective | Gives depth to cascade collapses even at steep angle |
| FOV | 60° | Moderate FOV; avoids wide-angle distortion |
| Camera angle (pitch) | 75° from horizontal | Almost top-down; ground plane is primary view, slight tilt shows pile depth and cascade direction |
| Camera height | 8–12 m above diorama floor | ⚠️ Provisional — calibrate against actual diorama scale in-engine |
| Camera position (XZ) | Centred over the diorama | Authored per-level via `CameraAnchor`; default is scene centre |
| Near clip | 0.1 m | Standard |
| Far clip | 100 m | Well beyond diorama scale |

⚠️ **Provisional:** FOV 60°, pitch 75°, and height 8–12 m are starting estimates.
Final values require in-engine calibration against actual diorama scale. Camera
angle especially affects how cascade collapses read — too steep and falling objects
disappear into the void without drama; too shallow and the ground plane is hard
to navigate.

**Placement:** the `Camera3D` is a scene-level node, not a child of the
`CameraAnchor`. At level start, Camera System copies the `CameraAnchor`'s global
transform to the `Camera3D`. The anchor remains in the scene hierarchy as a
reference marker only.

**Coupling note:** Input System's `sensitivity` and the camera's effective ground
coverage are coupled — changes to FOV, camera height, or angle require
`sensitivity` recalibration.

### Level Framing

Each level's camera framing is authored by placing the `CameraAnchor` node in
the level scene. Level designers should follow these guidelines:

**Framing rules:**
- The entire diorama floor must be visible from the anchor position — no
  consumable objects should spawn outside the camera frustum
- The hole's starting position (`HoleSpawn`) must be clearly visible at level start
- Goal objects should be readable from the default camera angle — avoid placing
  goal objects under overhangs or in areas where the 75° pitch obscures them

**Fallback:** if a level scene has no `CameraAnchor` node, Camera System logs a
warning and uses a default position: 10 m above world origin, looking straight
down at 90°. This ensures the game doesn't crash on a missing anchor, but the
fallback framing will likely be wrong for the level — treat it as a development
aid only.

**No camera animation:** Camera System does not animate the camera at level start
(no fly-in, no pan). The camera snaps to the anchor position instantly when the
level loads. Level intro animation, if added in future, is a separate post-MVP
concern.

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| Level Configuration | Reads from | Reads `CameraAnchor` transform at level start for base position |
| Growth System | Reads from | Receives `hole_level_up(new_level: int)` signal; reads `HoleProgressionConfig.level_height_multipliers[new_level - 1]` to set new target height |
| Level Flow System | Receives from | Resets camera to `anchor_height * level_height_multipliers[0]` on level restart |
| Input System | Indirect coupling | `sensitivity` must be recalibrated when camera height changes significantly — no runtime dependency |

## Formulas

### Camera Height per Hole Level

```
target_height = anchor_height * level_height_multipliers[hole_level - 1]
camera_y = lerpf(camera_y, target_height, 1.0 - exp(-zoom_speed * delta))
```

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| `anchor_height` | float (m) | 6–15 m | Y position of `CameraAnchor` — base height at hole level 1 |
| `level_height_multipliers` | Array[float] (10 values) | 1.0 – 3.0 | Per-hole-level scale factor; index 0 = level 1. Stored in `HoleProgressionConfig` |
| `hole_level` | int | 1–10 | Current hole level from Growth System |
| `target_height` | float (m) | `anchor_height` – `anchor_height * max_multiplier` | Height the camera interpolates toward |
| `zoom_speed` | float | 0.5–5.0 | Lerp speed; higher = snappier transition |
| `camera_y` | float (m) | Derived | Current camera height, updated every `_process` frame |

`lerpf` with `1.0 - exp(-zoom_speed * delta)` is framerate-independent — produces
consistent transition speed at 30 fps, 60 fps, and variable web frame rates.

⚠️ **Provisional:** default multiplier array `[1.0, 1.1, 1.2, 1.35, 1.5, 1.65, 1.8, 2.0, 2.2, 2.5]`
requires calibration against actual diorama scale and Growth System curve.

⚠️ **XZ drift note:** at 75° pitch (not 90°), raising camera height shifts the
effective view centre forward by `H * tan(15°)`. Level designers must account for
this drift when placing `CameraAnchor` — position the anchor so the diorama
remains centred at max height, not level-1 height.

**Example:** `anchor_height = 10 m`, level 5 multiplier = 1.5 → `target_height = 15 m`.

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|------------------|-----------|
| No `CameraAnchor` in scene | Warning logged; fallback to 10 m above world origin, 90° top-down | Development aid — wrong framing but no crash |
| `level_height_multipliers` array has fewer than 10 entries | Camera System clamps index to last available value and logs a warning | Prevents out-of-bounds access on a misconfigured array |
| Camera height overshoots diorama boundary (objects leave frustum at level 10) | Level designer's responsibility — tune `level_height_multipliers` and `anchor_height` together during playtest | Camera System has no awareness of scene boundaries |
| `hole_level_up` fires multiple times in rapid succession | Each signal updates `target_height`; lerp smooths out the transition — no jarring jump | Lerp absorbs rapid level changes gracefully |
| Level restart mid-zoom (camera between heights) | Camera snaps to `anchor_height * multipliers[0]` instantly on restart — no lingering zoom state | Clean slate on restart |
| Screen aspect ratio changes (browser window resize) | Godot adjusts perspective frustum automatically — no special case needed | Engine handles this natively |

## Dependencies

| System | Direction | Nature |
|--------|-----------|--------|
| Level Configuration | This depends on | Soft — reads `CameraAnchor` transform; has fallback if missing |
| Growth System | This depends on | Hard — receives `hole_level_up` signal to update target height; without it camera stays at base height |
| Level Flow System | This is depended on by (indirect) | Level restart signal triggers camera reset |

## Tuning Knobs

| Parameter | Default | Safe Range | Too High | Too Low |
|-----------|---------|------------|----------|---------|
| `fov` | 60° | 45°–75° | Barrel distortion at edges | Narrow view; level crops unless camera is very high |
| `camera_pitch` | 75° from horizontal | 65°–85° | Near top-down; cascade depth hard to read | Too side-on; ground plane hard to navigate |
| `anchor_height` (level 1) | 10 m | 6–15 m | Diorama looks tiny at level 1 | Parts of level outside frustum at level 1 |
| `level_height_multipliers` | [1.0, 1.1, 1.2, 1.35, 1.5, 1.65, 1.8, 2.0, 2.2, 2.5] | Per-value: 1.0–3.0 | Level 10 camera so high objects become unreadable | Camera barely moves across levels; growth feels unacknowledged. Stored in `HoleProgressionConfig` |
| `zoom_speed` | 2.0 | 0.5–5.0 | Camera snaps; level-up feels jarring | Camera lags far behind; disorienting when eating fast |

**Note:** `level_height_multipliers` should be tuned alongside the Growth System
point threshold curve — if the hole levels up faster, transitions happen faster
and `zoom_speed` may need adjustment.

## Acceptance Criteria

- [ ] `Camera3D` is positioned and rotated to match `CameraAnchor` transform at level start (level 1 height)
- [ ] On hole level-up, camera smoothly interpolates to `anchor_height * level_height_multipliers[new_level - 1]`
- [ ] Camera XZ position and pitch do not change during height transition
- [ ] Camera remains static between level-ups — no drift, no follow behaviour
- [ ] Missing `CameraAnchor` logs a warning and uses fallback (10 m, top-down) — no crash
- [ ] `level_height_multipliers` array with fewer than 10 entries logs a warning and clamps — no out-of-bounds crash
- [ ] Perspective projection confirmed; FOV matches configured value
- [ ] Camera resets to base height instantly on level restart — no lerp carry-over
- [ ] Entire diorama floor visible within frustum at hole level 1 for all authored levels

## Open Questions

| Question | Owner | Resolution |
|----------|-------|------------|
| Should camera height adapt automatically to diorama size, or always authored manually via `anchor_height`? Auto-fit could help level designers but adds complexity | Systems designer | Resolve during first level authoring pass |
