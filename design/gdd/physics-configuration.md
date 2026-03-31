# Physics Configuration

> **Status**: In Design
> **Author**: Design session + systems-designer
> **Last Updated**: 2026-03-31
> **Implements Pillar**: Web-Native Delight

## Overview

Physics Configuration defines the Godot 4.6 Jolt physics setup for Hungry Void.
It specifies the collision layer and mask assignments for every node type in the
game (hole, consumable objects, level geometry, level boundaries), the global
physics engine settings (gravity, tick rate, sleep thresholds), and the rules
for configuring new nodes added by future systems. No physics body or area in
the game should be placed in a scene without referencing this document. This
system has no player-facing behavior — it is pure infrastructure that enables
the Eating System's collision detection, the Object Spawner's RigidBody3D setup,
and the Hole Controller's Area3D monitoring to work correctly together.

## Player Fantasy

The player never sees or thinks about physics layers. What they feel is the
consequence: a world that behaves like a real place being consumed. Two moments
carry the fantasy. First, individual objects react with physical weight when
swallowed — they don't teleport away, they get pulled in. Second, and more
importantly, the **cascade collapse**: when the hole eats part of a pile or
stack, the objects above lose their support and tumble, topple, and avalanche
into or around the void. This "house of cards" effect — a bookshelf spilling,
a tower of crates cascading, a pile of fruit rolling — is the primary source
of surprise and delight in the game. Physics Configuration must treat this as
a first-class goal: rigid body settings (mass, friction, sleep thresholds,
damping) must be tuned so objects feel weighty and interconnected, collapse
animations read cleanly at the camera angle, and the engine never puts nearby
objects to sleep prematurely just because the frame budget is tight. Done
right, physics is invisible. Done wrong — objects jitter, phase through floors,
collapse too rigidly or not at all — and the power fantasy collapses with them.

## Detailed Design

### Core Rules

1. Every physics node in the game MUST be assigned a layer and mask from this
   document before being added to a scene. No default Godot layer assignments
   (layer 1, mask 1) are permitted in production scenes.
2. The hole's Area3D mask MUST only include `consumable`. It must never include
   `environment` or `boundary` — the hole cannot eat floors or walls.
3. Consumable objects MUST include `consumable` in their own collision mask to
   enable cascade collapse (objects push and topple each other).
4. Size-gating (can the hole eat this object?) is NOT handled by physics layers.
   It is handled in GDScript in the `body_entered` signal handler.
5. Global physics settings defined in this document are set in
   Project Settings → Physics and must not be overridden per-scene.

### Collision Layer Assignment

Godot 4 provides 32 named physics layers. Hungry Void uses four.

**Layer definitions** (set names in Project Settings → Layer Names → 3D Physics):

| Layer # | Name | Used By | Purpose |
|---------|------|---------|---------|
| 1 | `hole` | Hole Controller (Area3D) | The void. Monitors for consumable bodies entering its sphere. |
| 2 | `consumable` | All eatable scene objects (RigidBody3D) | Any object the hole can eat. The hole's Area3D mask watches this layer exclusively. |
| 3 | `environment` | Level geometry, floors, surfaces (StaticBody3D) | Diorama structure — objects rest on it. The hole ignores this layer entirely. |
| 4 | `boundary` | Level boundary trigger (Area3D) | Invisible perimeter — detects consumable objects that fall out of the playfield. |

**Mask rules** — what each node detects or collides with:

| Node Type | Collision Layer | Collision Mask | Meaning |
|-----------|----------------|----------------|---------|
| Hole (Area3D) | `hole` (1) | `consumable` (2) | Hole fires `body_entered` only for consumable objects |
| Consumable object (RigidBody3D) | `consumable` (2) | `consumable` + `environment` (2+3) | Objects rest on surfaces and interact with each other — enables cascade collapse |
| Environment geometry (StaticBody3D) | `environment` (3) | *(none)* | Passive surfaces — receive collisions, detect nothing |
| Boundary trigger (Area3D) | `boundary` (4) | `consumable` (2) | Detects consumables that fall off the level |

**Key design rationale:** consumable objects include `consumable` in their own
mask. This is what enables the cascade collapse — objects physically push and
topple each other because they collide with each other, not just with the floor.

### Node Type Guide

**Rule: `ConvexPolygonShape3D` and `ConcavePolygonShape3D` are forbidden on
`RigidBody3D`. All dynamic bodies use primitives only (Sphere, Box, Capsule).
This is a hard performance constraint for WebGL with 50–100 active bodies.**

| Game Object | Godot Node | Collision Shape | When to Use |
|-------------|-----------|----------------|-------------|
| Hole (void) | `Area3D` + `SphereShape3D` | Sphere, radius driven by Growth System | Always — hole is always spherical |
| Round/organic consumable | `RigidBody3D` + `SphereShape3D` | Sphere fitted to widest axis | Fruit, balls, heads, rounded items |
| Rectangular consumable | `RigidBody3D` + `BoxShape3D` | Box fitted to bounding box | Furniture, crates, books, appliances — default choice |
| Elongated consumable | `RigidBody3D` + `CapsuleShape3D` | Capsule along longest axis | Bottles, vases, pencils, poles |
| Floor / flat surface | `StaticBody3D` + `BoxShape3D` | Flat box | Tables, floors, shelves |
| Curved/irregular environment | `StaticBody3D` + `ConcavePolygonShape3D` | Mesh-accurate | Level geometry only — permitted on StaticBody3D since it never moves |
| Level boundary | `Area3D` + `BoxShape3D` | Box surrounding playfield | Catches consumables that fall off level |
| Goal object | Same as consumable | Same primitive as its size category | Goal status is a Godot group + `object_id` metadata flag, not a physics distinction |

**Compound shapes:** when a mesh genuinely requires two collision volumes
(e.g., an L-shaped sofa), use two primitive `CollisionShape3D` children on one
`RigidBody3D` node — Godot supports this natively. Maximum two shapes per body.

**Default rule:** when in doubt, use `BoxShape3D`. The slight visual mismatch
between mesh and box collider is imperceptible at the camera distances this
game uses, and box–box collision is the cheapest interaction in Jolt.

### Physics Engine Settings

Set in Project Settings. These are global — do not override per-scene.

| Setting | Value | Location | Rationale |
|---------|-------|----------|-----------|
| Physics engine | Jolt | Project Settings → Physics → 3D → Physics Engine | Default in Godot 4.6; better performance than Godot Physics for many simultaneous active rigid bodies |
| Physics ticks per second | 60 | Project Settings → Physics → Common → Physics Ticks Per Second | Matches target framerate; 30 makes collapse feel floaty, 120 is wasteful on web |
| Max physics steps per frame | 2 | Project Settings → Physics → Common → Max Physics Steps Per Frame | Prevents spiral-of-death on slow frames; allows mild catch-up without runaway cost |
| Gravity | 9.8 m/s² | Project Settings → Physics → 3D → Default Gravity | Standard gravity; objects feel grounded. Exposed as tuning knob |
| Sleep threshold (linear) | 0.1 m/s | Project Settings → Physics → Jolt → Sleep Velocity Threshold | **Critical.** Default (0.3) is too aggressive — objects sleep before finishing their topple. 0.1 keeps cascade fluid |
| Sleep threshold (angular) | 0.05 rad/s | Project Settings → Physics → Jolt → Sleep Angular Velocity Threshold | Same rationale — objects must keep rolling and tumbling until they truly settle |
| Sleep settle time | 0.5 s | Project Settings → Physics → Jolt → Sleep Time Threshold | Time a body must stay below sleep velocity before sleeping. Longer = more satisfying settle |
| CCD (continuous collision) | Off | Per `RigidBody3D` → CCD Mode | Objects move slowly — CCD is unnecessary overhead. Enable only if tunnelling is observed at high hole growth speeds |

**The sleep thresholds are the most important settings in this document.**
Leaving Godot defaults in place causes objects to freeze mid-topple, directly
breaking the cascade collapse fantasy.

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| Hole Controller | Reads from this | Uses layer `hole` (1) for its `Area3D.collision_layer`. Sets `Area3D.collision_mask` to `consumable` (2). `SphereShape3D` radius is owned by Growth System — Physics Configuration defines the shape type only |
| Object Spawner | Reads from this | Assigns layer `consumable` (2) and mask `consumable + environment` (2+3) to every `RigidBody3D` it instantiates. Shape type selected per Node Type Guide above |
| Eating System | Reads from this | Connects to `body_entered` on the Hole's `Area3D`. This config guarantees only `consumable` bodies trigger the signal — Eating System does not re-check the layer |
| Level Configuration | Reads from this | Level designers assign layer `environment` (3) to all `StaticBody3D` scene nodes. Boundary `Area3D` uses layer `boundary` (4), mask `consumable` (2) |
| Growth System | Writes to Hole Controller | On level-up, Growth System updates `SphereShape3D.radius` on the Hole's `Area3D`. Physics Configuration defines the shape contract; Growth System owns the radius value |

## Formulas

Physics Configuration has no gameplay formulas. The one formula-adjacent
concern is object mass, which is the primary tuning lever for cascade collapse
feel. Mass is assigned by the Object Spawner at spawn time using data from
Object Configuration.

### Object Mass Formula

```
mass = volume * density_multiplier
volume = width * height * depth   (bounding box, in metres)
```

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `volume` | float | 0.001 – 8.0 m³ | Object Configuration | Bounding box volume of the object |
| `density_multiplier` | float | 50 – 200 | Tuning knob | Global scalar; higher = heavier objects, more satisfying collapse |

**Expected output range:** 0.05 kg (tiny pebble) to 1600 kg (large furniture)

**Note:** Absolute mass values don't matter for feel — only mass *ratios* between
objects do. A stack of light objects on a heavy base produces the most satisfying
cascade. Level designers should compose piles with this ratio in mind.

**⚠️ Provisional:** Formula is theoretical — requires in-engine playtesting to
validate. The density_multiplier range especially needs hands-on tuning.

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|------------------|-----------|
| Object falls through floor | Not permitted. If observed: increase `StaticBody3D` box thickness to ≥ 0.2 m and enable CCD on the specific `RigidBody3D` | Thin colliders + fast small objects = tunnelling in Jolt |
| Hole grows into environment geometry | Hole `Area3D` mask excludes `environment` — no signal fires. Visual clipping may occur; accepted as a level design constraint | Eating floors would break the game; visual clipping is minor at camera distance |
| Two objects enter hole in the same frame | Both `body_entered` signals fire independently and are processed in sequence. Order is Jolt's internal step order; no conflict | Godot 4 signal queue handles multiple entries per frame correctly |
| Object falls off the level | Boundary `Area3D` detects it; object is freed. If it was a target, Level Flow System is notified — see Open Questions for resolution | Target loss is an edge case requiring explicit policy |
| Object sleeps mid-topple | Cannot happen if sleep thresholds are set per Physics Engine Settings. If observed in testing, reduce `Sleep Velocity Threshold` further | Premature sleep is the primary physics feel failure mode |
| Hole at max size (level 10) | `SphereShape3D` radius at maximum design value. No physics rule changes — size gating is handled by Eating System, not physics layers | No special physics case at max size |
| 50+ active rigid bodies simultaneously | If 60 fps budget is exceeded in WebGL, Object Spawner converts already-eaten objects to `StaticBody3D` before freeing, reducing active body count | Performance fallback — threshold value is a tuning knob |

## Dependencies

| System | Direction | Nature |
|--------|-----------|--------|
| Hole Controller | This is depended on by | Hard — cannot define `Area3D` layer/mask without this document |
| Object Spawner | This is depended on by | Hard — assigns layer/mask to every `RigidBody3D` it creates; values come from here |
| Eating System | This is depended on by | Hard — relies on the guarantee that only `consumable` bodies trigger `body_entered` |
| Level Configuration | This is depended on by | Hard — level designers assign `environment` and `boundary` layers per this spec |
| Growth System | This is depended on by | Soft — updates `SphereShape3D.radius`; the shape contract is defined here |
| Object Configuration | This is depended on by (soft) | Consumes the `collision_shape` enum values (box/sphere/capsule) defined in the Node Type Guide |
| *(none)* | This depends on | Foundation system — no upstream dependencies |

## Tuning Knobs

| Parameter | Default Value | Safe Range | Too High | Too Low |
|-----------|--------------|------------|----------|---------|
| `gravity` | 9.8 m/s² | 6.0 – 15.0 | Objects fall unrealistically fast; cascade feels violent/chaotic | Objects float and drift; collapse feels weightless |
| `density_multiplier` | 100 | 50 – 200 | Heavy objects barely move; cascade stalls | Objects fly on light contact; no satisfying thud |
| `sleep_velocity_threshold` | 0.1 m/s | 0.02 – 0.3 | Objects stay active forever; performance tanks | Objects freeze mid-topple; cascade looks broken |
| `sleep_angular_threshold` | 0.05 rad/s | 0.01 – 0.15 | Same as above | Objects stop spinning mid-roll |
| `sleep_settle_time` | 0.5 s | 0.2 – 1.5 | Long tail of settling costs physics budget | Objects snap to rest abruptly; no satisfying settle |
| `physics_ticks_per_second` | 60 | 30 – 60 | No benefit above 60; wastes frame budget | Collapse simulation becomes stepped and jittery |
| `max_physics_steps_per_frame` | 2 | 1 – 4 | Frame spikes on slow devices | Physics falls behind; objects teleport |
| `active_body_budget` | 80 | 40 – 120 | Frame rate drops in WebGL | Too few bodies; sparse levels with little cascade potential |

**Note:** `active_body_budget` is not a Godot setting — it is enforced by the
Object Spawner, which tracks active `RigidBody3D` count and degrades gracefully
when the budget is exceeded.

## Acceptance Criteria

- [ ] All 4 physics layer names are set in Project Settings → Layer Names → 3D Physics: `hole`, `consumable`, `environment`, `boundary`
- [ ] Hole `Area3D` fires `body_entered` when a `consumable` `RigidBody3D` enters its sphere — and does NOT fire for `environment` or `boundary` nodes
- [ ] A consumable object placed on an `environment` surface rests stably without jitter or sinking
- [ ] Removing one object from a stack of 3+ objects causes the remaining objects to topple and settle naturally (cascade collapse test)
- [ ] No objects tunnel through the floor under normal gameplay conditions (drop test: spawn 20 objects from 2 m height, zero tunnelling)
- [ ] An object falling off the level is detected by the boundary `Area3D`
- [ ] 80 simultaneous active `RigidBody3D` nodes maintain ≥ 60 fps in a Chrome WebGL build on mid-range hardware
- [ ] Physics engine confirmed as Jolt in Project Settings (not Godot Physics)
- [ ] Sleep thresholds match spec: linear 0.1 m/s, angular 0.05 rad/s, settle time 0.5 s
- [ ] No `ConvexPolygonShape3D` or `ConcavePolygonShape3D` exists on any `RigidBody3D` in any scene

## Open Questions

| Question | Owner | Resolution |
|----------|-------|------------|
| If a target object falls off the level, is the level unwinnable or does the Level Flow System handle it gracefully? | Level Flow System GDD | To be decided when Level Flow System is designed |
| What is the correct `density_multiplier` default? 100 is theoretical — needs hands-on tuning in first sprint | Gameplay programmer | Resolve during first physics spike |
| Do we need per-object `linear_damp` / `angular_damp` overrides for specific object types (e.g., rubber ball vs. metal crate), or is global gravity + mass sufficient? | Systems designer | Resolve during first level art pass |
