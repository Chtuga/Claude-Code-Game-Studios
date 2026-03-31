# Systems Index: Hungry Void

> **Status**: Draft
> **Created**: 2026-03-31
> **Last Updated**: 2026-03-31
> **Source Concept**: design/gdd/game-concept.md

---

## Overview

Hungry Void is a 3D casual arcade game built in Godot 4.6 with HTML5/WebGL
export. The player controls a void hole that eats any 3D object within its
size range, accumulating points to grow through 10 discrete size levels, and
must devour all marked target objects in a level before a countdown timer
expires. The system scope is deliberately small: a single core verb (eat),
a single growth mechanic (point thresholds), and a level-completion contract
(eat all targets). All other systems support these three. Physics-based
collision detection (Godot Jolt, Area3D/SphereShape3D) replaces manual
distance math. Monetization (ads + IAP) sits entirely outside the gameplay
loop and is designed last.

---

## Systems Enumeration

| # | System Name | Category | Priority | Status | Design Doc | Depends On |
|---|-------------|----------|----------|--------|------------|------------|
| 1 | Physics Configuration | Core | MVP | Designed | [physics-configuration.md](physics-configuration.md) | — |
| 2 | Object Configuration | Core | MVP | Designed | [object-configuration.md](object-configuration.md) | — |
| 3 | Level Configuration | Core | MVP | Designed | [level-configuration.md](level-configuration.md) | Object Configuration |
| 4 | Input System | Core | MVP | Designed | [input-system.md](input-system.md) | — |
| 5 | Timer System | Core | MVP | Designed | [timer-system.md](timer-system.md) | Level Configuration |
| 6 | Camera System | Core | MVP | Designed | [camera-system.md](camera-system.md) | Level Configuration, Growth System |
| 7 | Hole Controller | Gameplay | MVP | Designed | [hole-controller.md](hole-controller.md) | Input System, Physics Configuration |
| 8 | Object Spawner | Gameplay | MVP | Dropped | — | — | Objects pre-placed in .tscn by level designers; no runtime spawner needed for MVP |
| 9 | Growth System | Gameplay | MVP | Designed | [growth-system.md](growth-system.md) | Object Configuration |
| 10 | Target System | Gameplay | MVP | Designed | [target-system.md](target-system.md) | Level Configuration, Object Configuration |
| 11 | Level Flow System | Gameplay | MVP | Designed | [level-flow-system.md](level-flow-system.md) | Timer System, Target System | Includes star rating — computed at level completion |
| 12 | Visual Effects System | UI | MVP | Designed | [visual-effects-system.md](visual-effects-system.md) | Growth System, Object Configuration, Level Flow System |
| 13 | HUD System | UI | MVP | Designed | [hud-system.md](hud-system.md) | Timer System, Growth System, Target System, Object Configuration |
| 14 | Screen Flow System (inferred) | UI | Vertical Slice | Not Started | — | Level Flow System, Save System, World/Level Unlock System |
| 15 | Save System (inferred) | Persistence | Vertical Slice | Not Started | — | Level Flow System |
| 16 | World/Level Unlock System (inferred) | Progression | Vertical Slice | Not Started | — | Save System, Level Configuration |
| 17 | Level Select UI (inferred) | UI | Vertical Slice | Not Started | — | Save System, World/Level Unlock System |
| 18 | Audio System (inferred) | Audio | Vertical Slice | Not Started | — | Growth System, Level Flow System, Object Configuration |
| 19 | Ad Integration System | Meta | Alpha | Not Started | — | Level Flow System |
| 20 | IAP System | Meta | Alpha | Not Started | — | Save System, Screen Flow System |
| 21 | Cosmetic/Skin System | Gameplay | Full Vision | Not Started | — | IAP System, Hole Controller |
| 22 | Leaderboard System | Meta | Full Vision | Not Started | — | Save System, Level Flow System |

---

## Categories

| Category | Description | Systems in This Game |
|----------|-------------|----------------------|
| **Core** | Foundation systems everything else depends on | Physics Config, Object Config, Level Config, Input, Timer, Camera |
| **Gameplay** | Systems that make the game fun | Hole Controller, Growth, Target, Level Flow, Star Rating, Cosmetic/Skin |
| **Progression** | How the player advances over time | World/Level Unlock |
| **Persistence** | Save state and continuity | Save System |
| **UI** | Player-facing displays and screens | Visual Effects, HUD, Screen Flow, Level Select |
| **Audio** | Sound and music | Audio System |
| **Meta** | Systems outside the core loop | Ad Integration, IAP, Leaderboard |

---

## Priority Tiers

| Tier | Definition | Target Milestone | Systems |
|------|------------|------------------|---------|
| **MVP** | Core loop functional — can the player eat, grow, and win? | First playable (1–2 weeks) | 15 systems |
| **Vertical Slice** | One complete polished world with persistence | Polished demo (3–4 weeks) | 5 systems |
| **Alpha** | Monetization integrated, all worlds present | Alpha (5–6 weeks) | 2 systems |
| **Full Vision** | Content-complete, leaderboards, cosmetics | Release (7–8 weeks) | 2 systems |

---

## Dependency Map

### Foundation Layer (no dependencies)

1. **Physics Configuration** — Collision layers/masks must exist before any physics body is placed in the world
2. **Object Configuration** — Object size/point value data must be defined before any object can be spawned or eaten
3. **Level Configuration** — Diorama scene structure must be defined before levels can load or objects can be placed
4. **Input System** — Input abstraction (mouse/touch) must exist before the Hole Controller can read player intent
5. **Timer System** — Standalone countdown clock; nothing depends on it at foundation layer

### Core Layer (depends on Foundation)

1. **Camera System** — depends on: Level Configuration (camera positioned relative to diorama bounds)
2. **Hole Controller** — depends on: Input System, Physics Configuration (Area3D + SphereShape3D, collision layer assignment); owns `body_entered` handler, calls `eat()` on consumed objects

### Feature Layer (depends on Core)

1. **Growth System** — depends on: Object Configuration (point values); listens to `ConsumableObject.eaten` signal for point accumulation → threshold check → level-up event
2. **Target System** — depends on: Level Configuration (goal definitions), Object Configuration (object types); listens to `ConsumableObject.eaten` signal for goal progress
3. **Level Flow System** — depends on: Timer System (timeout = lose), Target System (all targets eaten = win); owns star rating (reads `timer.remaining` at win → 1/2/3 stars)

### Presentation Layer (depends on Features)

1. **Visual Effects System** — depends on: `ConsumableObject.eaten` signal (eat burst), Growth System (level-up flash + screen shake), Level Flow System (win/fail effects)
2. **HUD System** — depends on: Timer System, Growth System, Target System (reads state, renders overlay)
3. **Save System** — depends on: Level Flow System (persists star result emitted by `level_complete(stars)` on level complete)
4. **World/Level Unlock System** — depends on: Save System, Level Configuration (derives unlock state from star totals)
5. **Screen Flow System** — depends on: Level Flow System, Save System, World/Level Unlock System
6. **Level Select UI** — depends on: Save System, World/Level Unlock System

### Polish Layer

1. **Audio System** — depends on: `ConsumableObject.eaten` signal, Growth System, Level Flow System
2. **Ad Integration System** — depends on: Level Flow System (show interstitial on level complete)
3. **IAP System** — depends on: Save System, Screen Flow System
4. **Cosmetic/Skin System** — depends on: IAP System, Hole Controller
5. **Leaderboard System** — depends on: Save System, Level Flow System

---

## Recommended Design Order

| Order | System | Priority | Layer | Effort |
|-------|--------|----------|-------|--------|
| 1 | Physics Configuration | MVP | Foundation | S |
| 2 | Object Configuration | MVP | Foundation | S |
| 3 | Level Configuration | MVP | Foundation | M |
| 4 | Input System | MVP | Foundation | S |
| 5 | Timer System | MVP | Foundation | S |
| 6 | Camera System | MVP | Core | S |
| 7 | Hole Controller | MVP | Core | M |
| 8 | Growth System | MVP | Feature | S |
| 9 | Target System | MVP | Feature | S |
| 10 | Level Flow System | MVP | Feature | M |
| 11 | Visual Effects System | MVP | Presentation | M |
| 12 | HUD System | MVP | Presentation | S |
| 14 | Save System | Vertical Slice | Presentation | S |
| 15 | World/Level Unlock System | Vertical Slice | Presentation | S |
| 16 | Screen Flow System | Vertical Slice | Presentation | M |
| 17 | Level Select UI | Vertical Slice | Presentation | M |
| 18 | Audio System | Vertical Slice | Polish | M |
| 19 | Ad Integration System | Alpha | Polish | M |
| 20 | IAP System | Alpha | Polish | M |
| 21 | Cosmetic/Skin System | Full Vision | Polish | S |
| 22 | Leaderboard System | Full Vision | Polish | L |

*Effort: S = 1 session, M = 2–3 sessions, L = 4+ sessions*

Systems 1–5 (all Foundation) can be designed in parallel. Systems 8–11 can be
designed in parallel after #7.

---

## Circular Dependencies

None detected.

---

## High-Risk Systems

| System | Risk Type | Risk Description | Mitigation |
|--------|-----------|-----------------|------------|
| **Hole Controller + ConsumableObject** | Design + Technical | Core eat verb distributed between Hole Controller (`body_entered` → `eat()`) and each object's script (`eat()` → signal + `queue_free()`). Prototype validated mechanic feel; production must match. | Specify `eat()` contract in Object Configuration GDD. Spike early — every downstream system depends on the `eaten` signal firing correctly. |
| **Physics Configuration** | Technical | Godot 4.6 uses Jolt physics by default (changed from Godot Physics in 4.4). Layer/mask setup differs from pre-4.4 docs. Wrong setup = objects fall through hole or collisions never fire. | Cross-reference Godot 4.6 migration docs before designing. Use engine-reference/ directory. |
| **Hole Controller** | Technical + Design | The void visual (dark hole in a 3D world) needs a convincing shader approach — a plain dark sphere won't read as a void. | Design the GDD with a specific shader strategy; spike the visual early in the first sprint. |
| **Visual Effects System** | Scope | Juice is the #1 pillar ("Every Eat Feels Good"). GPUParticles3D in WebGL export has known performance constraints in Godot. | Cap particle count per eat event. Test on target hardware (mid-range laptop, Chrome) before committing to effect density. |

---

## Progress Tracker

| Metric | Count |
|--------|-------|
| Total systems identified | 22 |
| Design docs started | 12 |
| Design docs reviewed | 0 |
| Design docs approved | 0 |
| MVP systems designed | 12 / 12 |
| Vertical Slice systems designed | 0 / 5 |

---

## Next Steps

- [ ] Design MVP systems in order using `/design-system [system-name]`
- [ ] Run `/design-review` on each completed GDD
- [ ] Run `/gate-check pre-production` when all 15 MVP systems are designed
- [ ] Spike the Hole Controller shader early — highest visual risk
- [ ] Run `/setup-engine godot 4.6` to populate version-aware API references
