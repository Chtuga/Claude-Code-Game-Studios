# Technical Preferences

<!-- Updated: 2026-04-01 -->
<!-- All agents reference this file for project-specific standards and conventions. -->

## Engine & Language

- **Engine**: Godot 4.6.2 (`~/Desktop/Godot_v4.6.2`)
- **Language**: GDScript (static typing required on all public APIs)
- **Rendering**: Forward+ (3D, HTML5/WebGL export)
- **Physics**: Godot Jolt (default in 4.6)
- **Export Target**: HTML5/WebGL (primary); desktop for dev/debug convenience

## Naming Conventions

- **Classes**: `PascalCase` — e.g. `ConsumableObject`, `HoleController`, `HoleProgressionConfig`
- **Variables / functions**: `snake_case` — e.g. `accumulated_points`, `hole_level`, `eat()`
- **Signals**: `snake_case`, past tense for events — e.g. `eaten`, `hole_level_up`, `all_goals_complete`, `level_complete`
- **Files (.gd / .tscn / .tres)**: `snake_case` — e.g. `hole_controller.gd`, `hole_progression_config.tres`
- **Scenes**: `PascalCase.tscn` — e.g. `HoleController.tscn`, `Avocado.tscn`, `Level_01.tscn`
- **Constants / enums**: `SCREAMING_SNAKE_CASE` — e.g. `POINT_TIERS`, `MAX_HOLE_LEVEL`
- **Node groups**: `"snake_case"` strings — e.g. `"consumables"`, `"goal_objects"`
- **Metadata keys**: `snake_case` strings — e.g. `"object_id"`

## Performance Budgets

- **Target Framerate**: 60fps in Chrome on mid-range laptop
- **Frame Budget**: 16.6ms
- **Draw Calls**: ≤200 per frame (⚠️ provisional — validate after first in-engine profiling)
- **Memory Ceiling**: 256MB total (leaves headroom for WebGL overhead and browser tab)
- **Particle Cap**: 64 particles per burst effect (enforced by Visual Effects GDD)
- **Active RigidBody3D cap**: 100+ simultaneous at 60fps is the prototype-validated target

## Testing

- **Framework**: GUT (Godot Unit Testing addon)
- **Minimum Coverage**: All gameplay formula functions (Growth System thresholds, star rating, timer display, points bar fill)
- **Required Tests**: Balance formulas, ConsumableObject eat() contract, signal emission correctness, Growth System level-up loop, Target System goal counter logic

## Forbidden Patterns

- **No Autoload singletons for gameplay systems** — use dependency injection; systems are scene-local nodes, not globals. Exception: project-wide utility autoloads (e.g. a future `AudioBus` manager) require explicit approval.
- **No hardcoded gameplay values** — all tuning knobs (point thresholds, speed multipliers, radius multipliers, star thresholds) must live in `.tres` Resource files, never inline in `.gd` scripts.
- **No `instantiate()` calls during active gameplay** — all consumable objects are pre-placed in level `.tscn` files by designers. No runtime spawning.
- **No direct signal connections across unrelated systems** — systems connect to signals at level load and disconnect via scene teardown. No cross-scene signal wiring.
- **No physics body on the `Objects` Node3D container** — the parent grouping node must be a plain `Node3D` to avoid unintended physics interactions.

## Allowed Libraries / Addons

- **GUT** (Godot Unit Testing) — approved for `tests/` directory only; not shipped in export

## Architecture Decisions Log

<!-- Quick reference linking to full ADRs in docs/architecture/ -->
- [ADR-0001](../../docs/architecture/ADR-0001-core-gameplay-architecture.md) — ConsumableObject eat contract, signal-driven communication, HoleProgressionConfig as .tres, no runtime spawning
