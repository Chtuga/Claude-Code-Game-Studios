# Object Configuration

> **Status**: In Design
> **Author**: Design session + systems-designer
> **Last Updated**: 2026-03-31
> **Implements Pillar**: Grow Don't Grind / Every Eat Feels Good

## Overview

Object Configuration is the static data catalogue for all consumable objects in
Hungry Void. It defines every object type the game can spawn: its bounding box
dimensions, collision shape type, size category (used to assign growth point value
tiers), and whether it is eligible to be a target. No object may appear in a level
without a corresponding entry in this catalogue.

Each catalogue object scene must include a `ConsumableObject` script (see
Consumable Object Contract below). When the hole's `Area3D` fires `body_entered`,
the Hole Controller calls `eat()` on the object. The object is then responsible for
emitting the `eaten` signal (carrying `object_id` and `points`), triggering any
special effects, and calling `queue_free()` on itself.

Object Configuration is the single source of truth for object dimensions and point
tiers. Size categories are not used for the eating gate — they exist solely to assign
point tiers.

## Player Fantasy

The player never thinks about a data catalogue. What they feel is the consequence
of it: a sofa that tumbles differently than an apple, a fridge that's deeply
satisfying to finally reach the size for, a pile of books that's worth sweeping
even when no targets are nearby. Size category point tiers create the implicit
hierarchy — big objects feel like a prize, small objects feel like fuel. Done
right, the data is invisible. Done wrong — a tiny marble worth the same as a
washing machine, or a bookcase with the same physics weight as a pebble — and
the fantasy of consuming a real, physical world collapses.

## Detailed Design

### Size Categories

⚠️ **Provisional:** All bounding sphere radius ranges below are design estimates.
They must be validated in-engine during the first object art pass and adjusted to
match actual diorama scale and hole growth curve.

The bounding sphere radius is derived from each object's bounding box:
`r = sqrt(w² + h² + d²) / 2`. This is a reference value for level designers —
the actual size gate is handled by the Hole Controller / ConsumableObject eat
contract (see Object Configuration, Consumable Object Contract).

| Category | Bounding Sphere Radius | Accessible at Hole Level | Example Objects |
|----------|----------------------|--------------------------|-----------------|
| Small | 0.05 – 0.15 m | 1 | Fruit, mugs, books, shoes |
| Medium | 0.16 – 0.40 m | ~3 | Chairs, lamps, suitcases |
| Large | 0.41 – 0.90 m | ~6 | Sofas, fridges, bathtubs |
| Huge | 0.91 – 1.80 m | ~9 | Cars, trees, dumpsters |

**Rule:** when an object's bounding sphere radius falls near a category boundary,
assign it to the smaller category. This ensures the size gate (enforced by the
Hole Controller's `SphereShape3D` radius vs. the object's bounding sphere) errs
toward "edible sooner" rather than "gated longer," which matches the Grow Don't
Grind pillar.

### Point Value Formula

Points are awarded per category tier at the moment of eating. All values are
provisional — final numbers must be calibrated against the Growth System's
10-level threshold curve.

| Category | Points Awarded on Eat |
|----------|-----------------------|
| Small    | 10                    |
| Medium   | 40                    |
| Large    | 120                   |
| Huge     | 350                   |

⚠️ **Provisional:** These values are placeholders. Final calibration happens when
the Growth System GDD defines the full point threshold curve (levels 1–10). The
constraint to satisfy: a level with a typical object mix should allow the player
to reach the size needed for all targets through natural play, without exhausting
all objects before hitting required thresholds. See Growth System GDD (not yet
designed).

**Rule:** point value is determined by the object's size category at spawn time.
It does not change if the hole grows while the object is in the scene.

### Object Type Catalogue

Object Configuration defines the **data schema** every object entry must conform to.
The catalogue is populated world-by-world as level art is created — specific objects
are added during Level Configuration design, not here.

**Catalogue format:** each object type is a separate `.tres` Godot Resource file
(`class_name ObjectData extends Resource`). A central catalogue Resource holds an
array of all entries. Objects are pre-placed in level `.tscn` files by designers —
there is no runtime spawning from this catalogue.

Every entry must define these fields:

| Field | Type | Description |
|-------|------|-------------|
| `id` | string (kebab-case) | Unique identifier used in level data, logs, and design docs (e.g. `coffee-mug`, `park-bench`). Must match the `object_id` metadata on the corresponding scene node |
| `width` | float (m) | Bounding box X axis |
| `height` | float (m) | Bounding box Y axis |
| `depth` | float (m) | Bounding box Z axis |
| `collision_shape` | enum | `box`, `sphere`, or `capsule` — per Physics Configuration Node Type Guide |
| `size_category` | enum | `small`, `medium`, `large`, `huge` |
| `can_be_target` | bool | Whether this object type is eligible to appear in a level goal |
| `icon` | Texture2D | 2D icon used by HUD goal counters to represent this object type |

**Derived values** (computed at runtime, not stored in the catalogue):

- `bounding_sphere_radius = sqrt(width² + height² + depth²) / 2` — reference value for designers; actual size gate is the Hole Controller's `SphereShape3D.radius` vs. the object's collision shape
- `volume = width * height * depth` — used to compute mass via Physics Configuration formula
- `points = [tier lookup from size_category]` — emitted by `ConsumableObject.eaten` signal on eat event

### Consumable Object Contract

Every object scene must have a `ConsumableObject` base script attached to its root node:

```gdscript
class_name ConsumableObject
extends RigidBody3D

## Emitted when this object is eaten by the hole.
signal eaten(object_id: String, points: int)

@export var object_id: String   ## Must match catalogue id
@export var points: int         ## Populated from catalogue at load time

## Called by Hole Controller on body_entered.
## Subclasses may override to add special effects before calling super.eat().
func eat() -> void:
    eaten.emit(object_id, points)
    queue_free()
```

- `object_id` must match the catalogue entry `id` for Growth and Target Systems to react correctly
- `points` must be set from the catalogue `size_category` → point tier at level load
- Subclasses override `eat()` for special behaviours (spawn items, explode, etc.) — must still call `super.eat()` or manually emit `eaten` and call `queue_free()`
- Objects that are not catalogue entries (environment, boundary) must NOT have `ConsumableObject` and must be on a different collision layer so the hole's `Area3D` never detects them

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| Hole Controller | This is called by | On `body_entered`, Hole Controller calls `eat()` on this object (duck-typed) |
| Growth System | This is depended on by | Subscribes to `ConsumableObject.eaten` signal for point accumulation |
| Target System | This is depended on by | Subscribes to `ConsumableObject.eaten` signal for goal progress; reads `can_be_target` to validate level target assignments |
| HUD System | This is depended on by | Reads `icon` field by `object_id` to display per-type goal counter icons |
| Level Configuration | Reads from this | References objects by `id` when authoring which objects appear in a level |
| Physics Configuration | No runtime dependency | Defines the `collision_shape` enum values and the mass formula that consumes `volume` — Object Configuration respects those contracts but does not call into Physics Configuration at runtime |

## Formulas

### Bounding Sphere Radius

```
bounding_sphere_radius = sqrt(width² + height² + depth²) / 2
```

| Variable | Type | Source | Description |
|----------|------|--------|-------------|
| `width`, `height`, `depth` | float (m) | Object catalogue | Bounding box dimensions |
| `bounding_sphere_radius` | float (m) | Derived | Reference value for level designers when sizing holes and level layouts |

⚠️ **Provisional:** Expected output range 0.04 – 1.56 m depends on validated size
category radius ranges.

### Point Value Lookup

```
points = POINT_TIERS[size_category]

POINT_TIERS = { small: 10, medium: 40, large: 120, huge: 350 }
```

| Variable | Type | Source | Description |
|----------|------|--------|-------------|
| `size_category` | enum | Object catalogue | Category assigned at authoring time |
| `points` | int | Lookup | Growth points awarded to player on eat |

⚠️ **Provisional:** Values 10/40/120/350 require calibration against the Growth
System's 10-level threshold curve (not yet designed).

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|------------------|-----------|
| Object added to a level with no catalogue entry | Error logged, object not spawned. Object Spawner must validate `id` exists before instantiating | Prevents silent missing-object bugs in levels |
| `can_be_target: false` object designated as target in a level | Level Configuration validation rejects it at design time, not runtime | Target System relies on this flag being correct — catch it early |
| Object dimensions result in `bounding_sphere_radius` that crosses a category boundary | Assign to smaller category per the boundary rule in Size Categories. Flag in level review if the mismatch is large (>20%) | Avoids objects being gated longer than their visual size suggests |
| Two catalogue entries with the same `id` | Treated as a configuration error — last entry wins with a warning logged. `id` must be unique | Duplicate IDs would cause unpredictable point values or wrong scenes loading |
| Object with zero or negative dimension | Invalid entry — catalogue validation must reject it at load time | Zero volume produces zero mass; negative dimensions are physically meaningless |
| Object node in level scene has `object_id` that doesn't match any catalogue `id` | `ConsumableObject.eat()` emits `eaten` with 0 points and logs a warning; Target System logs an error if the object is in the `"goal_objects"` group | Catches authoring mismatches between placed objects and catalogue entries |

## Dependencies

| System | Direction | Nature |
|--------|-----------|--------|
| Hole Controller | This is depended on by | Hard — calls `eat()` on `ConsumableObject` on `body_entered`; objects must implement this method |
| Growth System | This is depended on by | Hard — subscribes to `ConsumableObject.eaten` for points; relies on correct `points` value set at load |
| Target System | This is depended on by | Hard — subscribes to `ConsumableObject.eaten` for goal progress; relies on `can_be_target` flag and `object_id` metadata |
| HUD System | This is depended on by | Hard — reads `icon` field by `object_id` for goal counter display |
| Level Configuration | This is depended on by | Hard — level data references objects by `id`; catalogue must exist before any level can be authored |
| Physics Configuration | This depends on (soft) | Defines the `collision_shape` enum values (box/sphere/capsule) and mass formula that consumes `volume` — Object Configuration must respect these contracts |
| *(none)* | Foundation system | No other upstream dependencies beyond Physics Configuration |

## Tuning Knobs

| Parameter | Default Value | Safe Range | Too High | Too Low |
|-----------|--------------|------------|----------|---------|
| `points_small` | 10 | 5 – 30 | Small objects feel over-rewarded; player ignores large objects | Small objects feel pointless to chase |
| `points_medium` | 40 | 20 – 100 | Medium objects trivialize growth; player never needs large ones | Medium objects not worth the detour |
| `points_large` | 120 | 60 – 300 | Large objects make small ones irrelevant | Large objects feel under-rewarded for their size |
| `points_huge` | 350 | 150 – 800 | Huge objects alone can complete a level; strategic choice eliminated | Huge objects feel like a disappointment to finally reach |
| Size category radius ranges | See Size Categories table | Validated in-engine | Objects gated longer than their visual size suggests; frustration | Objects accessible too early; growth curve flattened |

**Note:** The ratio between tiers matters more than absolute values. The current
1:4:12:35 ratio creates a clear hierarchy. Compress it (e.g. 1:2:4:8) and large
objects lose their prize feel; expand it too far (1:10:100:1000) and small objects
become noise.

## Acceptance Criteria

- [ ] Every object in a level has a corresponding entry in the Object Configuration catalogue with all required fields populated
- [ ] `id` values are unique across the entire catalogue — duplicate IDs are rejected at load time with an error
- [ ] Objects with zero or negative dimensions are rejected at load time
- [ ] `bounding_sphere_radius` is correctly derived from catalogue dimensions
- [ ] Eating a small object awards exactly 10 points (via `ConsumableObject.eaten` signal); medium 40; large 120; huge 350
- [ ] An object with `can_be_target: false` cannot be designated as a target in Level Configuration — validation catches it before the level loads
- [ ] Each catalogue object scene root node has a `ConsumableObject` script; calling `eat()` emits `eaten(object_id, points)` and calls `queue_free()`
- [ ] Environment and boundary objects are NOT on collision layer 2 — the hole's `Area3D` does not detect them

## Open Questions

| Question | Owner | Resolution |
|----------|-------|------------|
| What are the correct size category radius ranges in metres? 0.05–1.80 m is theoretical — requires first object art pass and in-engine playtesting | Gameplay programmer + level designer | Resolve during first physics spike with real object scenes |
| Should point tier values be stored in Object Configuration or in Growth System? Currently split: tiers defined here, thresholds defined in Growth System (`HoleProgressionConfig`). | Systems designer | ✅ Resolved: split is intentional — per-object point value lives here, per-level growth thresholds live in `HoleProgressionConfig` owned by Growth System |
| Does any object type need per-instance variation (e.g. small/large variant of the same mesh)? If so, catalogue needs versioned entries (`coffee-mug-sm`, `coffee-mug-lg`) vs. a single entry with a size parameter | Level designer | Resolve during first level art pass |
