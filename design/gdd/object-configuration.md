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
without a corresponding entry in this catalogue. This system has no runtime logic —
it is a data resource read by the Object Spawner (to instantiate RigidBody3D nodes
with correct shapes and mass), the Eating System (to award growth points on eat),
and the Target System (to identify which objects can be marked as ★ targets). The
eating size gate is a direct radius comparison handled by the Eating System — size
categories are not used for gating. Object Configuration is the single source of
truth for object dimensions and point tiers.

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
`r = sqrt(w² + h² + d²) / 2`. This is the value the Eating System compares
against the hole's `SphereShape3D` radius for the size gate.

| Category | Bounding Sphere Radius | Accessible at Hole Level | Example Objects |
|----------|----------------------|--------------------------|-----------------|
| Small | 0.05 – 0.15 m | 1 | Fruit, mugs, books, shoes |
| Medium | 0.16 – 0.40 m | ~3 | Chairs, lamps, suitcases |
| Large | 0.41 – 0.90 m | ~6 | Sofas, fridges, bathtubs |
| Huge | 0.91 – 1.80 m | ~9 | Cars, trees, dumpsters |

**Rule:** when an object's bounding sphere radius falls near a category boundary,
assign it to the smaller category. This ensures the Eating System's size gate errs
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

**Derived values** (computed at runtime, not stored in the catalogue):

- `bounding_sphere_radius = sqrt(width² + height² + depth²) / 2` — used by Eating System for size gate
- `volume = width * height * depth` — used to compute mass via Physics Configuration formula
- `points = [tier lookup from size_category]` — used by Eating System on eat event

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| Object Spawner | Reads from this (if it exists) | Objects are pre-placed in level scenes; Spawner (if implemented) applies physics setup only — reads `collision_shape` to validate `CollisionShape3D` type and `width/height/depth` to compute `volume` for mass assignment |
| Eating System | Reads from this | Reads `size_category` → point tier on `body_entered`; reads `bounding_sphere_radius` (derived) for size gate comparison against hole radius |
| Target System | Reads from this | Reads `can_be_target` to validate that a level's designated targets are eligible object types |
| Level Configuration | Reads from this | References objects by `id` when authoring which objects appear in a level and at what positions |
| Physics Configuration | No runtime dependency | Defines the `collision_shape` enum values and the mass formula that consumes `volume` — Object Configuration respects those contracts but does not call into Physics Configuration at runtime |

## Formulas

### Bounding Sphere Radius

```
bounding_sphere_radius = sqrt(width² + height² + depth²) / 2
```

| Variable | Type | Source | Description |
|----------|------|--------|-------------|
| `width`, `height`, `depth` | float (m) | Object catalogue | Bounding box dimensions |
| `bounding_sphere_radius` | float (m) | Derived | Compared against hole `SphereShape3D` radius by Eating System for size gate |

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
| Object node in level scene has `object_id` metadata that doesn't match any catalogue `id` | Eating System logs a warning and awards 0 points; Target System logs an error if it's in the `"goal_objects"` group | Catches authoring mismatches between placed objects and catalogue entries |

## Dependencies

| System | Direction | Nature |
|--------|-----------|--------|
| Object Spawner | This is depended on by (if it exists) | Soft — objects are pre-placed; Spawner reads `collision_shape` and dimensions for physics setup only. Object Spawner system is not confirmed for MVP |
| Eating System | This is depended on by | Hard — cannot award points without the point tier lookup; cannot perform size gate without `bounding_sphere_radius` |
| Target System | This is depended on by | Hard — relies on `can_be_target` flag to validate level target assignments |
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
- [ ] `bounding_sphere_radius` is correctly derived from catalogue dimensions — exact eating gate behaviour (which hole level can eat which size category) is validated in the Eating System GDD once hole radius growth curve is defined
- [ ] Eating a small object awards exactly 10 points; medium 40; large 120; huge 350
- [ ] An object with `can_be_target: false` cannot be designated as a target in Level Configuration — validation catches it before the level loads
- [ ] Object Spawner correctly selects `BoxShape3D`, `SphereShape3D`, or `CapsuleShape3D` based on `collision_shape` field
- [ ] Deleting a scene file and loading a level that references its UID logs a warning and skips the object — no crash

## Open Questions

| Question | Owner | Resolution |
|----------|-------|------------|
| What are the correct size category radius ranges in metres? 0.05–1.80 m is theoretical — requires first object art pass and in-engine playtesting | Gameplay programmer + level designer | Resolve during first physics spike with real object scenes |
| Should point tier values be stored in Object Configuration or in Growth System? Currently split: tiers defined here, thresholds defined in Growth System. Confirm this split is intentional once Growth System GDD is written | Systems designer | Resolve when Growth System GDD is designed |
| Does any object type need per-instance variation (e.g. small/large variant of the same mesh)? If so, catalogue needs versioned entries (`coffee-mug-sm`, `coffee-mug-lg`) vs. a single entry with a size parameter | Level designer | Resolve during first level art pass |
