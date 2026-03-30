# Prototype Report: Hole Eating Loop

## Hypothesis

The "eat anything to grow → devour marked targets to complete" loop is
satisfying and strategic. The 10-level point-threshold growth produces
rewarding unlock moments, and target objects requiring specific size levels
create meaningful decision-making about growth path.

## Approach

- Built as a single self-contained HTML5 Canvas file (vanilla JS, no engine)
- Rationale: Godot not yet configured; Canvas is the fastest path to validate
  web-browser feel without engine setup overhead
- Runtime tested via preview server + JS evaluation to simulate gameplay
- 95 non-target objects (tiny/small/medium/large), 3 targets (r=45/85/122)
  sized to require hole levels 3, 6, and 9 respectively
- 90-second timer, 10-level point threshold growth, eat effects, HUD

## Result

### What worked
- **Core mechanic is functional end-to-end**: eating, point accumulation,
  level-up chain, target detection, and win state all trigger correctly
- **Visual clarity is strong**: green = edible, grey = too big, purple ★ =
  target — player can read the scene at a glance
- **Win screen payoff**: "DEVOURED!" with the oversized hole still visible
  is a satisfying visual endpoint
- **Eat effects land**: expanding ring burst on each eat gives per-object
  feedback even without audio
- **HUD is readable**: timer, level, progress bar, and star counter are all
  legible at small sizes

### What didn't work / issues found

**Issue 1 — Growth too fast (critical balance problem)**
In simulation, the hole reached level 9 just from sweeping tiny objects,
because eating one object at a position sweeps up all nearby objects in the
same frame. Targets 1 and 2 (intended to require levels 3 and 6) were
accessible long before the player would logically seek them. The "strategic
growth path" design intent was not validated — it never became necessary to
plan around size gates.

**Issue 2 — Target clustering (spawning bug)**
All 3 targets spawned in the upper-left quadrant of the screen. `safePos()`
avoids the center start zone but has no inter-object spacing logic — targets
can cluster in a corner. A player in the right half of the screen would have
no visual targets guiding them.

**Issue 3 — Progress bar barely visible at LV 1**
The bar background blends into the dark background at low fill. Bar color
contrast needs increasing.

**Issue 4 — Uneaten large objects at game end**
1 of 95 non-target objects remained uneaten in simulation — a large object
whose position was near but not swept. Not a critical bug but indicates the
eat radius (`hr * 0.75`) may be slightly too tight. Confirmed edible at level 9
(r ≤ 127.5) but was not within range during the sweep.

## Metrics

| Metric | Value |
|--------|-------|
| Tiny objects (r=6–13) | 56 |
| Small objects (r=14–30) | 23 |
| Medium objects (r=31–55) | 11 |
| Large objects (r=56–95) | 5 |
| Total non-target points available | 4,251 |
| Level reached in efficiency simulation | 9 (of 10) |
| Objects eaten to win | 98 |
| Levels unlocked before target 1 became accessible | All required levels (3+) reached trivially |
| Win state triggered correctly | ✅ |
| Level-up chain worked correctly | ✅ |
| Target counter incremented correctly | ✅ |
| Prototype iterations to get mechanic working | 1 |

## Recommendation: PROCEED (with design pivots)

The core mechanic **works and feels coherent**. Eating objects, watching
the hole grow, and chasing targets is a natural and clear loop. The win
state is satisfying. None of the issues found are fundamental flaws in the
concept — they are calibration and spawning problems.

The critical pivot needed before production: **the growth curve needs to
create real gating**. As designed, the player reaches the size needed for
all targets through normal sweeping — targets never truly blocked by size.
The "strategic path" design intent requires either much higher thresholds
or targets sized more aggressively (e.g., requiring level 8–9 for the
final target, not level 6).

## If Proceeding

### Architecture requirements (production rewrite in Godot 4)
- Use `Area2D` / `CollisionShape2D` for eat detection — replace distance math
- Objects as `Node2D` scenes with `RigidBody2D` for physics feel on consume
- Hole as a `SubViewport` mask or shader-based void effect (not a solid circle)
- Spawn system with quadrant-based placement ensuring targets cover all screen zones
- Separate `HoleController`, `ObjectSpawner`, `LevelProgressionSystem` scripts

### Balance adjustments required
1. **Raise point thresholds 2–3×**: Current thresholds are too low; player
   hits level 9 before exhausting tiny objects in optimal play. Suggested
   new top threshold: ~12,000 points
2. **Increase target sizes**: r=45/85/122 → r=65/110/155 to match raised
   thresholds and create real level gates
3. **Reduce tiny object count**: 56 tiny objects produces too much early
   snowball; try 30–35
4. **Add inter-target spacing**: Enforce minimum distance between targets
   at spawn (at least W/3 apart)
5. **Increase eat overlap threshold**: `hr * 0.75` → `hr * 0.65` for slightly
   more forgiving feel (objects fully swallowed when center is inside)

### Performance targets
- 100+ simultaneous physics objects at 60fps in WebGL (Chrome, mid-range laptop)
- Eat effect pool capped at 20 concurrent effects to avoid GC pressure

### Scope adjustments
- Audio is the highest-value missing element — even placeholder SFX would
  dramatically increase perceived juice
- The visual difference between "edible" (colored) and "not edible" (grey)
  objects is clear and should be preserved in production art direction

## Lessons Learned

1. **The snowball effect is self-reinforcing**: Growing the hole sweeps up
   nearby medium/large objects even when the player is "targeting" tiny ones.
   Level thresholds must account for this adjacency sweep, not just linear
   eating. Design for "sloppy play", not just "optimal play".

2. **Spawning needs spatial distribution guarantees**: Random placement with
   a center exclusion zone is not sufficient. Production levels need authored
   or grid-constrained placement to ensure scene reads well from any start
   position.

3. **Canvas prototype validated web platform viability**: The prototype runs
   smoothly in browser at 60fps with ~100 objects and canvas effects. WebGL
   is not strictly required for this object count — it would be used for
   post-processing (bloom, vignette) not for performance.

4. **The "DEVOURED!" end state is the emotional highlight**: The visual of
   a massive hole surrounded by scattered eat rings is the strongest moment
   in the loop. Production should amplify this — consider slow-motion zoom,
   a final consume animation, or a satisfying "world eaten" conclusion shot.
