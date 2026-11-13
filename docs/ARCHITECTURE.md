# Architecture

Status: **Milestone 3** (player interaction; main menu, options and highscore storage pulled
forward from M5). Sections marked *(planned)* describe the target
design that later milestones implement; they exist so early code does not paint us into a corner.

## Directory layout

```
rodeo_game/                    Godot project root (res://) = Git root
├── project.godot              engine/project settings
├── export_presets.cfg         Android preset (iOS preset added in Milestone 6)
├── icon.svg                   app icon source
├── CLAUDE.md / README.md
├── .vscode/                   workspace settings, debugger launch configs
├── docs/          (.gdignore) setup, deployment, architecture
├── tools/         (.gdignore) setup_windows.ps1, build_android.ps1
├── build/         (ignored)   exported APK/AAB
├── src/                       all game code + scenes, one folder per system
│   ├── boot/                  M1  device_check: platform smoke test / diagnostics
│   ├── game/                  M2  game.tscn/gd: gameplay scene, wires the systems per physics tick
│   ├── physics/               M2  RotationalState, RotationalIntegrator, InitialStateGenerator,
│   │                              SimulationConfig (pure GDScript, no Nodes)
│   ├── debris/                M2  DebrisDefinition resource, Debris node (model + collision pivot)
│   ├── surface/               M2  SurfaceMaterial resource (ablation efficiency)
│   ├── laser/                 M2  LaserConfig, AblationModel (pure), LaserEmitter (ray-cast + visuals)
│   ├── core/                  M3  ScenePaths (scene switching), Platform (platform decisions)
│   │                          M4  game_manager (autoload), game states, countdown, timer
│   ├── input/                 M3  AimInput + JoystickAimInput + MotionAimInput, AimConfig,
│   │                              MultiTouchControl -> TouchJoystick / TouchButton / TouchSlider,
│   │                              InputActions (desktop keyboard)
│   ├── ui/                    M3  main menu + panels (options, highscores, credits), GameHUD,
│   │                              border-glow shader, reticle, SafeAreaContainer, theme/
│   ├── persistence/           M3  Settings + Highscores autoloads, HighscoreTable (pure)
│   └── audio/                 M5  audio manager (autoload)
├── data/                      M2  tunable .tres instances
│   ├── debris/envisat.tres        mass properties, spin limits, model reference
│   ├── laser/default_laser.tres   power, focus range, coupling, gameplay gain
│   ├── simulation/default_simulation.tres
│   └── surfaces/default_surface.tres
├── assets/models/envisat_placeholder/   M2  primitive-based Envisat stand-in (mesh + collision)
└── tests/                     M2  headless unit tests (run_tests.gd + support/test_case.gd)
```

### Replacing the Envisat placeholder with a real model

1. Import the model (`.glb` preferred) into `assets/models/envisat/`.
2. Create a wrapper scene: the imported model + an `AnimatableBody3D` (layer 2 "debris",
   `sync_to_physics` off) with simple `CollisionShape3D`s (boxes/convex hulls; avoid trimesh).
   Keep the model's axes: long axis = X, ASAR side = −Y (matches the inertia tensor).
3. Point `model_scene` in `data/debris/envisat.tres` to the wrapper and update `center_of_mass_m`.
No code changes are needed.

**Decision – feature folders under `src/` (scene + script side by side)** instead of separate
`scenes/` and `scripts/` trees. A system is then one folder, which keeps the "separate systems"
requirement visible in the file tree. Raw assets (`assets/`) and tunable data (`data/`) stay
separate because artists/designers touch them independently of code.

**Decision – Godot project at the repository root** (instead of a `game/` subfolder). Godot,
VS Code's godot-tools and CI all find `project.godot` without extra configuration. Non-game folders
get a `.gdignore` so Godot does not scan them.

## Key technical decisions

### 1. Rotational dynamics: own integrator, not `RigidBody3D` (M2)

| Option | Pros | Cons |
|---|---|---|
| **A. Own rigid-body rotation model in GDScript (recommended)** | Full inertia tensor and torque-free precession (Euler's equations) under our control; deterministic fixed step; testable headlessly without a scene; exact angular-momentum bookkeeping (ΔL = r × J); trivially swappable for better models | We write ~150 lines of math ourselves |
| B. Godot `RigidBody3D` + `apply_impulse()` | Little code | Physics engine (Jolt / Godot Physics) adds damping, sleeping, solver tolerances; inertia handling is opaque; hard to guarantee that a shot's physical torque direction alone decides speed-up vs. slow-down |

The debris node is a plain `Node3D`/`StaticBody3D` whose transform is **written from** the
simulation every frame. Godot's physics server is used **only for ray queries** against the
debris collision shape (hit point + surface normal).

Implemented interfaces (pure `RefCounted`, no scene dependency):

```
RotationalState        orientation q (body->world), angular momentum L (world, N·m·s),
                       body inertia tensor I_b (Basis)
                       angular_velocity_world(): ω = R · I_b⁻¹ · Rᵀ · L
                       apply_impulse(r, J) -> ΔL = r × J;  kinetic_energy() = ½ ω·L
RotationalIntegrator   step(state, dt): torque-free, L constant, RK4 on dq/dt = ½ ω ⊗ q,
                       renormalized; optional sub-steps. Subclass for richer models.
InitialStateGenerator  random orientation + random axis + |ω| in the definition's limits
```

**Tick order** (`src/game/game.gd`, `_physics_process`, fixed 60 Hz): aim → ray-cast →
recoil force → `apply_impulse(r, F·dt)` → integrate → write orientation to the debris node.

**Translation is not simulated.** The recoil also pushes the debris linearly; we assume the
servicer station-keeps relative to the target. Only the rotational effect matters for the game.

**Precision:** Godot vectors are float32. Tests show < 0.01 % energy drift over 100 s.

### 2. Laser–ablation impulse model (M2)

Per physics step while firing, the ray hit gives point `p`, outward normal `n`, beam direction `d`:

```
incidence     cos θ = max(0, −d · n)            (no effect on grazing / back faces)
fluence term  depends on laser power P, focus f (slider), spot area A(f)
impulse       J = −n · C_m · η_surface · P · cos θ · g(f) · Δt     (recoil pushes into the surface)
torque        ΔL = (p − c) × J
```

`C_m` (momentum coupling, N/W), `η_surface` (ablation efficiency), and `g(f)` are configurable
resources. The recoil is along the **surface normal**, not the beam, which is what makes aiming
strategic: the same beam on a tilted panel produces a different torque.

**Time scaling:** real laser de-tumbling of Envisat (~8 t, ~2–4 °/s) takes days to weeks. We keep
realistic geometry/inertia and SI units and apply one documented **gameplay gain** on `C_m` (and,
if needed, on the initial spin limits) so a session lasts ~1–3 minutes. All physics stays
self-consistent; only the coupling constant is "game-balanced".

Current values (`data/laser/default_laser.tres`): P = 10 kW, C_max = 50 µN/W, I_half = 30 kW/m²,
spot radius 5 cm (focus 1) … 1 m (focus 0), gain = 200 (raised from 50 in M3 for faster play).
Physical recoil at full focus ≈ 0.49 N; in game ≈ 98 N. On the solar array (lever ≈ 13 m) that
is ≈ 1 300 N·m, i.e. up to ≈ 0.6 °/s² of spin change against initial rates of 2–5 °/s. The
player's *laser power* option scales P by 50–150 %. Final balancing with the completion rule (M4).

**Envisat data** (`data/debris/envisat.tres`): mass 7 828 kg, principal moments ≈ (17 023,
124 826, 129 112) kg·m² about (long axis X, Y, Z) – approximate values of the magnitude reported in
the Envisat attitude literature, principal axes assumed aligned with the model. Initial spin
2–5 °/s (observed tumble rates were roughly 2.7–3.5 °/s). Replace with better data when available.

### 3. Data-driven debris and surfaces (M2, extended later)

`DebrisDefinition` (custom `Resource`, one `.tres` per object): display name, model scene, mass,
centre of mass, inertia tensor, collision shape source, default `SurfaceMaterial`, initial-spin
limits. Adding a rocket stage later = new `.tres` + model; no code changes.
Surface zones (reflective panels, fragile parts, damage) attach `SurfaceMaterial`s to collision
shapes/mesh surfaces – the hook exists from M2, the zones themselves are a future feature.

### 4. Input abstraction (M3, implemented)

```
AimInput (base)        update_aim(angles, dt) -> angles   yaw/pitch [rad] relative to the
                       boresight (laser -> debris CoM), limited to a cone (AimConfig, 30°)
                       direction_from_angles(boresight, angles) -> beam direction
 ├── JoystickAimInput  RATE control (FPS look stick): dead zone, power response curve,
                       smoothed rate; releasing the stick holds the aim
 └── MotionAimInput    ABSOLUTE tilt control relative to a calibrated neutral gravity vector:
                       roll -> yaw, pitch -> pitch; dead zone + smoothing; gravity sensor
                       (fused accel+gyro) with low-pass accelerometer fallback; cannot drift
```

The laser only receives a beam direction, a focus value and a firing flag; it never knows which
input method produced them. The active `AimInput` is created from `Settings.aim_method`.

Touch widgets (`MultiTouchControl` subclasses) read touch events directly, so the joystick, FIRE
and the FOCUS slider work simultaneously (Godot's Buttons only react to the first finger).

**Feedback:** the game measures the laser-induced change of |ω| per tick
(`(|ω| after impulse − |ω| before) / dt`), smooths it, and the HUD shows it as a number and as
a full-screen border glow: green = slowing, red = speeding up, intensity ∝ magnitude.

### 5. Game flow and autoloads (M4/M5)

Autoloads are limited to true app-wide services: `GameManager` (state machine:
`MENU → COUNTDOWN → RUNNING ⇄ PAUSED → COMPLETED`), `Settings`, `Highscores`, `AudioManager`.
Systems talk via **signals** (e.g. `debris_stabilized`, `laser_fired`) rather than reaching into
each other. Completion rule: |ω| < threshold continuously for the stabilisation period (both
configurable in a `GameRules` resource).

Persistence uses `ConfigFile` under `user://` (`settings.cfg`, `highscores.cfg`). `user://` maps to
app-private storage on Android and iOS, so no storage permissions are needed.

### 6. Rendering: Mobile renderer with OpenGL fallback

| Option | Notes |
|---|---|
| Forward+ | Desktop-class; too heavy for phones |
| **Mobile (chosen)** | Vulkan on Android, Metal on iOS; good 3D lighting at mobile cost |
| Compatibility | OpenGL ES 3 – widest device support, fewer features; also needed for Web |

`rendering/rendering_device/fallback_to_opengl3=true` lets devices without a usable Vulkan driver
start on OpenGL automatically. The renderer can be switched later without code changes (only
some visual effects differ).

### 7. Platform layer and iOS readiness

- Game code uses only cross-platform Godot APIs (`Input.get_gravity()`, touch events,
  `user://`, `DisplayServer.get_display_safe_area()`). Platform branches go through
  `OS.has_feature("android" | "ios" | "mobile")`, kept in one place.
- iOS export needs macOS + Xcode (Godot generates an Xcode project). Bundle ID will reuse the
  reverse-DNS id `com.rodeogames.laserdetumbling`.
- Apple guidelines discourage a *Quit* button: the main menu's *Exit Game* is hidden on iOS.
- Textures use ETC2/ASTC compression (enabled), which both platforms support.
- Landscape is `sensor landscape` (both landscape directions); the motion-aiming code must
  re-calibrate if the orientation flips.

## Current Android configuration

| Setting | Value |
|---|---|
| Package | `com.rodeogames.laserdetumbling` (fix before first store upload – it can never change afterwards) |
| Version | from `application/config/version` (0.1.0); `version/code` must increase every store upload |
| Min / target SDK | 24 (Android 7.0) / 36 – Godot 4.7 defaults |
| ABI | arm64-v8a only (all phones since ~2017; add armeabi-v7a only if old devices matter) |
| Export type | Standard APK from prebuilt templates (no Gradle). Gradle/AAB in Milestone 6 |
| Orientation | Sensor landscape, immersive fullscreen |
| Permissions | none |
| Base resolution | 1280×720, stretch `canvas_items` / `expand` (UI scales, wider phones see more) |
