# Sprint 01 — 2026-04-01 to 2026-04-07

## Sprint Goal

Core loop playable end-to-end in Godot 4.6: the hole moves, eats objects, grows
through 10 levels, and the level completes when all targets are consumed before
time runs out.

## Capacity

- Total days: 5
- Buffer (20%): 1 day reserved for unplanned work, debugging, Godot API surprises
- Available: 4 days

---

## Tasks

### Must Have (Critical Path)

| ID | Task | Est. | Dependencies | Acceptance Criteria |
|----|------|------|-------------|---------------------|
| S1-01 | **Godot project setup** — create project, configure Jolt physics, set collision layers/masks per Physics Configuration GDD (hole=1, consumable=2, environment=3, boundary=4) | 0.5d | — | Project opens; Layer/mask names visible in Project Settings; no physics warnings |
| S1-02 | **ConsumableObject base script** — `class_name ConsumableObject extends RigidBody3D`, `eaten` signal, `eat()` → emit + `queue_free()`, `object_id` + `points` exports | 0.5d | S1-01 | Calling `eat()` on a test object emits `eaten(object_id, points)` and frees the node |
| S1-03 | **HoleProgressionConfig.tres** — create resource class + first `.tres` file with placeholder values (base_radius, radius_multipliers×10, point_thresholds×9, speed_multipliers×10) | 0.5d | S1-01 | Resource loads without error; all arrays have correct lengths; values editable in Inspector |
| S1-04 | **HoleController** — `Area3D` + `SphereShape3D`, mouse/touch movement, `max_speed` cap, XZ bounds clamp, Y-axis lock, `body_entered` → `body.eat()` duck-typed call | 1d | S1-01, S1-02, S1-03 | Hole moves with mouse; cannot leave play bounds; eating a ConsumableObject triggers `eaten` signal |
| S1-05 | **GrowthSystem** — connects to `eaten` on `"consumables"` group, accumulates points, level-up loop, emits `hole_level_up(new_level)`; updates `SphereShape3D.radius` on level-up | 0.5d | S1-02, S1-03, S1-04 | Eating objects accumulates points; hitting threshold emits `hole_level_up`; hole radius visually increases |
| S1-06 | **TargetSystem** — connects to `eaten` on `"goal_objects"` group, `goal_counters` dict, emits `all_goals_complete` when all counters = 0 | 0.5d | S1-02 | Eating a goal object decrements its counter; eating all goal objects emits `all_goals_complete` |
| S1-07 | **TimerSystem** — countdown from `LevelConfig.time_limit`, emits `time_up` and `time_changed(remaining, is_urgent)` (urgent ≤15s), supports `start()` / pause / resume / `add_time(30)` | 0.5d | — | Timer counts down; `time_up` fires at 0; `is_urgent` true at ≤15s; `add_time(30)` adds correctly |
| S1-08 | **LevelFlowSystem (basic)** — `WAITING_FOR_FIRST_TOUCH` → `GAMEPLAY` → `WIN`/`FAIL`; calls `start()` on all systems on first touch; 0.3s win delay; star rating from `timer.remaining` vs `star_thresholds`; emits `level_complete(stars)` and `level_failed` | 1d | S1-04, S1-05, S1-06, S1-07 | Level starts on first input; `all_goals_complete` triggers win with correct star count; `time_up` triggers fail |
| S1-09 | **First playable level scene** — `Level_01.tscn` with Level scene hierarchy (Environment, Boundary, Objects, HoleSpawn, CameraAnchor); 10–15 consumables in `"consumables"` group, 3 in `"goal_objects"`; placeholder geometry; `LevelConfig.tres` with star thresholds | 0.5d | S1-01, S1-02 | Scene loads; hole spawns at HoleSpawn; eating consumables fires signals; win triggers on eating 3 targets |

**Must Have total**: ~5.5 sessions (fits within 4 days at full-time pace)

---

### Should Have

| ID | Task | Est. | Dependencies | Acceptance Criteria |
|----|------|------|-------------|---------------------|
| S1-10 | **Basic HUD** — `CanvasLayer` with timer display (`MM:SS`), hole level indicator, goal counter (text only — no icons yet); urgent style (red) on timer | 0.5d | S1-07, S1-05, S1-06 | Timer counts down visibly; level indicator updates on `hole_level_up`; goal counter decrements on eat |
| S1-11 | **Void shader spike** — prototype a `ShaderMaterial` on `HoleMesh`: dark void with rim glow or edge distortion; fallback to dark `StandardMaterial3D` if WebGL compile fails | 0.5d | S1-01 | Shader compiles and renders in the editor; fallback material applied if shader fails; visual reads as a void not a solid sphere |

---

### Nice to Have

| ID | Task | Est. | Dependencies | Acceptance Criteria |
|----|------|------|-------------|---------------------|
| S1-12 | **Floating score text** — `Label3D` rises from eaten object position and fades over 0.6s; size scales with size category | 0.5d | S1-02, S1-04 | `+[points]` text appears on eat; fades within 0.6s; large objects show larger text |
| S1-13 | **HoleProgressionConfig calibration** — adjust `point_thresholds` and `radius_multipliers` based on prototype report findings (raise thresholds 2–3×; real gating at levels 3, 6, 9) | 0.25d | S1-03, S1-05, S1-09 | Playing the level requires intentional growth to reach target sizes; not trivially reachable from tiny-object sweeping |

---

## Carryover from Previous Sprint

No previous sprint.

---

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Void shader fails to compile for WebGL | Medium | Medium | Design fallback to `StandardMaterial3D` dark sphere; shader is S1-11 (Should Have) — does not block core loop |
| Jolt `body_entered` fires on non-consumable layers | Low | High | Enforce layer 2 mask on `Area3D` per Physics Config GDD; `has_method("eat")` guard in HoleController |
| GDScript static typing errors on Godot 4.6 API | Medium | Medium | Cross-reference `docs/engine-reference/godot/` before each API call; Godot 4.6 has post-cutoff changes |
| Point thresholds too low / snowball effect (prototype finding) | High | Medium | S1-13 addresses this; if not reached this sprint, calibrate in Sprint 2 before adding more objects |
| Sprint scope too large for 1 week | Low | Medium | S1-10 through S1-13 are Should Have / Nice to Have — core loop (S1-01 to S1-09) is the hard floor |

---

## Dependencies on External Factors

- Godot 4.6.2 installed and accessible at `~/Desktop/Godot_v4.6.2`
- No external asset dependencies for Sprint 1 — placeholder geometry is sufficient

---

## Definition of Done for this Sprint

- [ ] All Must Have tasks (S1-01 through S1-09) completed
- [ ] Level_01.tscn is playable end-to-end: hole moves → eats → grows → targets eaten → win state triggers
- [ ] Win screen shows correct star count based on time remaining
- [ ] `time_up` correctly triggers fail state
- [ ] No crashes or null reference errors during normal play
- [ ] `HoleProgressionConfig.tres` values are editable in Inspector (not hardcoded)
- [ ] Godot project is committed to `src/` with `.gitignore` configured for Godot exports

---

## Notes

**From prototype report (apply to this sprint):**
- Growth too fast at current thresholds — raise `point_thresholds` 2–3× in S1-13
- Target spacing: place 3 targets in different quadrants of Level_01 manually
- `eat()` overlap threshold: use `SphereShape3D` radius fully (not `hr * 0.75`) — Godot's Area3D handles this geometrically

**Key GDD references:**
- Physics layers: `design/gdd/physics-configuration.md`
- ConsumableObject contract: `design/gdd/object-configuration.md`
- HoleController spec: `design/gdd/hole-controller.md`
- Growth System + HoleProgressionConfig: `design/gdd/growth-system.md`
- Level scene hierarchy + groups: `design/gdd/level-configuration.md`
- Level Flow states: `design/gdd/level-flow-system.md`
