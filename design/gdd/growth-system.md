# Growth System

> **Status**: In Design
> **Author**: Design session + systems-designer
> **Last Updated**: 2026-04-01
> **Implements Pillar**: Grow Don't Grind / Every Eat Feels Good

## Overview

The Growth System accumulates points from eaten objects and drives hole progression
through 10 discrete size levels. It subscribes to the `ConsumableObject.eaten`
signal on every consumable in the level, adds the object's point value to a running
total, and checks it against the threshold for the next level in
`HoleProgressionConfig`. When the threshold is crossed, it emits
`hole_level_up(new_level: int)` — the signal that causes the Hole Controller to
expand the void and the Camera System to zoom out. Points and hole level reset to
zero and level 1 respectively at the start of every level. The Growth System owns
`HoleProgressionConfig` as a preloaded data resource and is the single source of
truth for all per-level progression arrays (point thresholds, speed multipliers,
camera height multipliers, radius growth).

## Player Fantasy

Growth should feel like momentum, not arithmetic. Each eat nudges the bar; the bar
fills; the hole *surges* — and for a moment the world that felt too big suddenly
feels manageable. The level-up is the emotional payoff for every small eat that
preceded it. Done right, players chase the level-up the way a pinball player chases
the multiball: it's the thing that makes everything else feel worth doing.

The system is background infrastructure, but its output — the level-up moment — is
a first-class sensation. It must never feel arbitrary (the bar should be readable
and the next threshold visible) and never feel grindy (there should always be
edible objects nearby to keep the bar moving).

## Detailed Design

### Core Rules

1. At level start: `accumulated_points = 0`, `hole_level = 1`
2. At level load the Growth System connects to `eaten(object_id, points)` on every
   node in the `"consumables"` group
3. On each `eaten` signal: `accumulated_points += points`
4. After each addition, process level-ups in a loop:
   ```
   while hole_level < 10 and accumulated_points >= point_thresholds[hole_level - 1]:
       hole_level += 1
       emit hole_level_up(hole_level)
   ```
5. At level 10, points continue accumulating (for HUD display) but the loop does
   not run
6. On level reset or new level start: `accumulated_points = 0`, `hole_level = 1`,
   reconnect signals to new scene's consumables

### States and Transitions

The Growth System has no state machine. It exists only within the level scene and
is destroyed when the scene unloads. It exposes a `start()` method called by the
Level Flow System when gameplay begins — this initializes `accumulated_points = 0`,
`hole_level = 1`, and connects to `eaten` signals on all consumables. Before
`start()` is called, signals are not connected and no points are processed.

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| Object Configuration | Reads from | Preloads `HoleProgressionConfig.tres` at startup; no runtime calls to Object Configuration |
| ConsumableObject | Reads from | Connects to `eaten(object_id: String, points: int)` on each consumable at `start()` |
| Level Flow System | Reads from | Receives `start()` call on gameplay begin — triggers signal connection and state initialization |
| Hole Controller | Emits to | Emits `hole_level_up(new_level: int)` — Hole Controller updates `SphereShape3D.radius`, `HoleMesh.scale`, and `effective_speed` |
| Camera System | Emits to | Emits `hole_level_up(new_level: int)` — Camera System updates target height via `level_height_multipliers` |
| HUD System | This is depended on by | HUD reads `accumulated_points: int` and `hole_level: int` as readable properties |
| Visual Effects System | Emits to | Emits `hole_level_up(new_level: int)` — VFX System triggers level-up flash and screen shake |

**Readable properties:**
```gdscript
var accumulated_points: int   # total points this level — authoritative score
var hole_level: int           # current hole level (1–10)
```

## Formulas

### HoleProgressionConfig Structure

```gdscript
class_name HoleProgressionConfig
extends Resource

@export var base_radius: float                     # radius at level 1
@export var radius_multipliers: Array[float]       # 10 values — index 0 = level 1 (1.0)
@export var point_thresholds: Array[int]           # 9 values — points to reach levels 2–10
@export var speed_multipliers: Array[float]        # 10 values — index 0 = level 1 (1.0)
@export var level_height_multipliers: Array[float] # 10 values — index 0 = level 1 (1.0)
```

### Point Accumulation

```
accumulated_points += points   # points from ConsumableObject.eaten
```

### Level-Up Check (per eat, loop until no threshold crossed)

```
while hole_level < 10 and accumulated_points >= point_thresholds[hole_level - 1]:
    hole_level += 1
    emit hole_level_up(hole_level)
```

| Variable | Type | Source | Description |
|----------|------|--------|-------------|
| `accumulated_points` | int | Runtime | Running total this level; resets to 0 on level start |
| `hole_level` | int | Runtime | Current level (1–10); resets to 1 on level start |
| `point_thresholds[i]` | int | `HoleProgressionConfig` | Points required to reach level `i+2` |

### Radius Formula

```
sphere_radius = base_radius * radius_multipliers[hole_level - 1]
```

### Provisional Values

⚠️ All values below are provisional — the game designer will calibrate manually
after first playtest.

| Parameter | Provisional Value |
|-----------|------------------|
| `base_radius` | 0.2 m |
| `radius_multipliers` | `[1.0, 1.15, 1.3, 1.5, 1.7, 1.95, 2.2, 2.5, 2.85, 3.2]` |
| `point_thresholds` | `[100, 200, 300, 400, 500, 600, 700, 800, 900]` (linear, 100pt steps) |
| `speed_multipliers` | `[1.0, 1.1, 1.2, 1.3, 1.45, 1.6, 1.75, 1.9, 2.1, 2.3]` |
| `level_height_multipliers` | `[1.0, 1.1, 1.2, 1.35, 1.5, 1.65, 1.8, 2.0, 2.2, 2.5]` |

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|------------------|-----------|
| Single eat crosses multiple thresholds (e.g. huge object at level 1) | Loop fires `hole_level_up` once per crossed threshold — hole can jump multiple levels in one eat | Intentional; validated in playtests. Dishonest to cap it |
| `accumulated_points` reaches threshold exactly | Level-up fires (`>=` not `>`) | Exact hits should reward, not frustrate |
| `start()` called while consumables are still being freed from previous level | Only connect signals on nodes currently in the scene tree; freed nodes are not reachable | Level scene teardown must complete before `start()` is called — Level Flow System responsibility |
| `HoleProgressionConfig` arrays have wrong length (not 10/9 values) | Log an error at load time; clamp index access to prevent crashes | Catches authoring errors before they cause runtime panics |
| Hole is already at level 10 when an object is eaten | `accumulated_points` increments, loop does not run, no signal emitted | Level 10 is the hard cap |
| `eaten` signal fires after level end (object was mid-fall when level completed) | Ignored — Growth System is destroyed with the scene or `start()` was never called again | Scene lifecycle handles this naturally |

## Dependencies

| System | Direction | Nature |
|--------|-----------|--------|
| Object Configuration | This depends on (soft) | Owns `HoleProgressionConfig.tres` whose values must be calibrated against Object Configuration point tiers; no runtime call |
| ConsumableObject | This depends on | Hard — Growth System connects to `eaten` signal at `start()`; no signal = no point accumulation |
| Level Flow System | This depends on | Hard — `start()` must be called to activate; without it no signals connect and points never accumulate |
| Hole Controller | This is depended on by | Hard — subscribes to `hole_level_up` to update radius, speed, and mesh scale |
| Camera System | This is depended on by | Hard — subscribes to `hole_level_up` to update target height |
| HUD System | This is depended on by | Soft — reads `accumulated_points` and `hole_level` as readable properties |
| Visual Effects System | This is depended on by | Soft — subscribes to `hole_level_up` for level-up flash and screen shake |

## Tuning Knobs

All per-level arrays live in `HoleProgressionConfig.tres` — edit the `.tres` file
directly, no code changes needed.

| Parameter | Default | Safe Range | Too High | Too Low |
|-----------|---------|------------|----------|---------|
| `base_radius` | 0.2 m | 0.1 – 0.5 m | Level 1 already eats medium objects; no growth arc | Hole too small to eat anything at start; frustrating |
| `radius_multipliers` | see Formulas | 1.0 – 4.0 per value; must be non-decreasing | Level 10 hole swallows entire level; no challenge | Growth feels invisible; player doesn't notice level-ups |
| `point_thresholds` | 100pt linear steps | Designer-set; no formula constraint | Growth feels slow and grindy | Player hits level 10 before eating half the level |
| `speed_multipliers` | see Formulas | 1.0 – 3.0 per value; must be non-decreasing | High-level hole moves too fast to control precisely | No perceptible speed increase; growth feels unrewarded |
| `level_height_multipliers` | see Formulas | 1.0 – 3.0 per value; must be non-decreasing | Camera too far; objects become unreadable | Camera barely moves; growth feels unacknowledged |

**Note:** All five arrays are tuned together — `point_thresholds` controls the
*pace* of level-ups; the multiplier arrays control the *feel* of each one. Changing
thresholds without revisiting multipliers (or vice versa) will produce an unbalanced
curve.

## Acceptance Criteria

- [ ] `start()` initializes `accumulated_points = 0` and `hole_level = 1` and
      connects to all consumables in the scene
- [ ] Eating an object increments `accumulated_points` by the correct point value
      from `ConsumableObject.eaten`
- [ ] When `accumulated_points` crosses a threshold, `hole_level_up(new_level)` is
      emitted with the correct new level
- [ ] A single eat that crosses multiple thresholds emits `hole_level_up` once per
      crossed threshold in ascending order
- [ ] At level 10, further eats increment `accumulated_points` but no
      `hole_level_up` is emitted
- [ ] `HoleProgressionConfig` arrays of incorrect length (not 10/9 values) log an
      error at load time and do not crash
- [ ] `accumulated_points` and `hole_level` are readable from HUD System without
      calling into Growth System logic
- [ ] Calling `start()` on a fresh level scene produces identical initial state
      regardless of prior level's outcome

## Open Questions

| Question | Owner | Resolution |
|----------|-------|------------|
| Are provisional `point_thresholds` (100pt linear steps) appropriate given point tiers of 10/40/120/350? At 100pt steps a player eating only small objects needs 10 eats per level — may feel grindy at early levels | Game designer | Resolve during first playtest |
| Should `radius_multipliers` be non-decreasing by validation, or trusted to the designer? A mis-ordered array would cause the hole to shrink | Gameplay programmer | Resolve during implementation sprint |
