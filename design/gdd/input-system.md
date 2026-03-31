# Input System

> **Status**: In Design
> **Author**: Design session + systems-designer
> **Last Updated**: 2026-03-31
> **Implements Pillar**: Every Eat Feels Good / Web-Native Delight

## Overview

The Input System translates player drag gestures into 2D movement commands for
the Hole Controller. It uses a virtual trackpad model: clicking or touching
anywhere on the screen begins a drag session, and the hole moves in the same
direction and proportion as the drag delta each frame. The hole never snaps to
the cursor position — it accumulates relative displacement. This model works
identically for mouse (desktop browser) and touch (mobile browser) and avoids
the problem of a finger obscuring the hole on small screens. The Input System
outputs a `movement_delta: Vector2` per input event — a world-space XZ
displacement the Hole Controller applies to the hole's position. Emitting per
event (not per physics frame) avoids polling overhead and keeps the input path
lean on web. Boundary clamping is the Hole Controller's responsibility; the
Input System outputs raw unclamped delta.

## Player Fantasy

The hole feels like an extension of the player's hand. There's no aiming, no
cursor to find — just drag and the void follows. On desktop the mouse becomes a
drawing tool; on mobile a finger swipe steers the hole naturally without ever
needing to tap precisely on it. Speed matters: a slow deliberate drag manoeuvres
the hole through tight gaps between objects; a fast sweep sends it lunging at a
pile. The input should feel immediate and low-friction — the moment a player
touches the screen, they're in control. Any perceptible lag between gesture and
hole movement breaks the fantasy of being the void.

## Detailed Design

### Input Sources

The Input System handles two event sources, unified behind the same virtual
trackpad logic:

**Mouse (desktop browser)**

| Event | Action |
|-------|--------|
| `InputEventMouseButton` (LEFT, pressed) | Begin drag session — record start position |
| `InputEventMouseMotion` (while button held) | Accumulate `relative` delta → emit `movement_delta` |
| `InputEventMouseButton` (LEFT, released) | End drag session — zero out delta |

- The system cursor is **never hidden** during gameplay.
  `Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)` is the permanent state.
  This keeps UI elements accessible and avoids disorientation on web.
- Only left mouse button initiates a drag. Right click and scroll wheel are ignored.

**Touch (mobile browser)**

| Event | Action |
|-------|--------|
| `InputEventScreenTouch` (pressed) | Begin drag session — record `index 0` touch position |
| `InputEventScreenDrag` | Accumulate `relative` delta → emit `movement_delta` |
| `InputEventScreenTouch` (released) | End drag session |

- Only the first touch (`index == 0`) is tracked. Multi-touch is ignored.
- The entire screen is the trackpad surface — no dead zones.

**Unified output:** both sources emit the same `movement_delta: Vector2` signal
to the Hole Controller per input event. The Hole Controller has no knowledge
of which input source produced it.

### Screen-to-World Mapping

With the virtual trackpad model, no raycasting is needed. Screen pixel delta maps
directly to world-space XZ displacement via a scalar conversion factor:

```
world_delta = screen_delta_pixels * sensitivity
movement_delta = Vector2(world_delta.x, world_delta.y)
                 → maps to Vector3(world_delta.x, 0, world_delta.y) in Hole Controller
```

The `sensitivity` factor converts pixels to metres. Its value depends on the
camera's field of view, zoom level, and the physical scale of the diorama — it
is a tuning knob, not a derived constant.

⚠️ **Provisional:** sensitivity default requires in-engine calibration once Camera
System and diorama scale are established. A starting estimate of `0.01`
(1 pixel = 1 cm of hole movement) is a reasonable first guess for a room-scale
diorama viewed from above.

**Coordinate mapping:** Godot's screen X axis maps to world X; screen Y axis maps
to world **Z** (not Y — the hole moves on the XZ plane, not XY). The Y (vertical)
component is always 0 — the hole never moves up or down.

### Input Smoothing

The Input System outputs raw pixel delta with no smoothing applied. Smoothing is
explicitly **not** implemented here for two reasons:

1. The virtual trackpad model already feels responsive by nature — the hole moves
   exactly as far as the drag, so there's no perceived snap or teleport to smooth out
2. Smoothing in the input layer would introduce lag that fights the "immediate
   control" player fantasy

If smoothing is needed for feel, it belongs in the **Hole Controller** (as
interpolation on the hole's position), not here. The Input System's contract is:
accurate, low-latency delta delivery, every physics frame.

**Zero-delta behaviour:** when no drag is active (mouse button up / no touch),
`movement_delta` is `Vector2.ZERO`. The Hole Controller is responsible for
deciding whether the hole decelerates, stops instantly, or continues with momentum.
Input System always reports exactly what the player is doing.

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| Hole Controller | Receives from this | Subscribes to `movement_delta: Vector2` signal per input event; applies delta to hole world position after clamping to level bounds |
| HUD System | No dependency | HUD does not read input state — it reads hole position from Hole Controller |
| Level Flow System | Indirect | Input System is disabled when Level Flow System signals level complete, level failed, or pause state; re-enabled on level start |
| Camera System | No dependency | Camera is fixed per level; it does not respond to input |

**Signal definition:**
```gdscript
signal movement_delta(delta: Vector2)  # emitted per input event during active drag
```

## Formulas

### Pixel-to-World Conversion

```
movement_delta = screen_delta * sensitivity

where:
  screen_delta   = Vector2  — pixel displacement this frame (from InputEventMouseMotion.relative
                              or InputEventScreenDrag.relative)
  sensitivity    = float    — world metres per screen pixel (tuning knob)
  movement_delta = Vector2  — XZ world displacement, passed to Hole Controller
```

| Variable | Type | Range | Source |
|----------|------|-------|--------|
| `screen_delta` | Vector2 (px) | Unbounded | Godot input event `.relative` |
| `sensitivity` | float | 0.005 – 0.03 | Tuning knob, default 0.01 ⚠️ Provisional |
| `movement_delta` | Vector2 (m) | Unclamped | Output to Hole Controller |

**Example:** drag of 50 px at sensitivity 0.01 → `movement_delta = Vector2(0.5, 0)`
→ hole moves 0.5 m in world X.

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|------------------|-----------|
| Mouse button released outside the browser window | Drag session ends — next `InputEventMouseButton` press starts a fresh session. No stuck drag state | Browser loses mouse-up events when cursor leaves window; must handle gracefully |
| Touch interrupted by phone call / notification | `InputEventScreenTouch` released event may not fire. Input System resets drag state on next input event if `Input.get_touch_count() == 0` — no active touches means drag ended | Mobile OS interruptions can drop touch-end events |
| Two fingers touch simultaneously | Only `index == 0` is tracked; second touch ignored. If index 0 is lifted while index 1 is active, drag ends — index 1 does not take over | Keeps touch handling simple; prevents accidental zoom or two-finger confusion |
| Very fast drag (flick gesture) | Large `screen_delta` in one frame → large `movement_delta`. Hole Controller is responsible for clamping to level bounds. Input System does not cap delta magnitude | Input accuracy is more important than safety; Hole Controller owns boundary logic |
| Player clicks on a UI element (button, HUD) | UI events are consumed by Godot's CanvasLayer before reaching the game viewport — no drag session begins | Godot's input propagation handles this natively; no special case needed |
| Level not yet loaded / Input System enabled before level is ready | `movement_delta` signal fires but Hole Controller is not yet connected — signal is ignored. No crash | Godot signals with no connected receivers are safe no-ops |

## Dependencies

| System | Direction | Nature |
|--------|-----------|--------|
| Hole Controller | This is depended on by | Hard — consumes `movement_delta` signal to move the hole; Input System is useless without a receiver |
| Level Flow System | This depends on (soft) | Input System must be disabled during level complete / failed / pause states — Level Flow System owns those state transitions and notifies Input System |
| *(none)* | Foundation system | No upstream data dependencies — reads only from Godot's built-in input events |

## Tuning Knobs

| Parameter | Default Value | Safe Range | Too High | Too Low |
|-----------|--------------|------------|----------|---------|
| `sensitivity` | 0.01 m/px | 0.005 – 0.03 | Hole rockets across the level on small drags; impossible to navigate precisely | Hole barely moves; player has to swipe repeatedly to cross the level |

**Note:** sensitivity is the only tuning knob in this system. It should be
calibrated once Camera System and diorama scale are established. On mobile, the
effective sensitivity may feel different from desktop due to finger contact area
— consider exposing separate `sensitivity_mouse` and `sensitivity_touch` values
if playtesting reveals a mismatch.

## Acceptance Criteria

- [ ] Dragging the mouse (left button held) moves the hole in the same direction as the drag on both X and Z axes
- [ ] Touch drag on mobile browser moves the hole identically to mouse drag — same sensitivity, same coordinate mapping
- [ ] System cursor remains visible at all times during gameplay on desktop — `Input.MOUSE_MODE_VISIBLE` confirmed in browser
- [ ] Releasing the mouse button or lifting the finger stops hole movement — `movement_delta` returns `Vector2.ZERO`
- [ ] Releasing mouse outside the browser window ends the drag session — no stuck movement on re-entry
- [ ] Clicking a HUD button does not initiate a drag session — UI input is consumed before reaching the Input System
- [ ] Two simultaneous touches: only the first touch drives movement; second touch has no effect
- [ ] `movement_delta` is `Vector2.ZERO` when Input System is disabled (level complete / failed state)
- [ ] A 50 px drag at default sensitivity (0.01) produces exactly `Vector2(0.5, 0)` or `Vector2(0, 0.5)` world-space delta depending on drag axis

## Open Questions

| Question | Owner | Resolution |
|----------|-------|------------|
| Should `sensitivity_mouse` and `sensitivity_touch` be separate tuning knobs? Single value is simpler; split may be needed if playtesting shows mobile feel differs from desktop | Gameplay programmer | Resolve during first mobile playtest |
| Should Input System be an Autoload (singleton) or a node attached to the level scene? Autoload is simpler for global disable/enable; scene node is more portable | Lead programmer | Resolve during first implementation sprint |
