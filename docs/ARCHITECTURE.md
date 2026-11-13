# Architecture

Status: **Milestone 1** (environment). Sections marked *(planned)* describe the target design that
later milestones implement; they exist so early code does not paint us into a corner.

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
└── src/                       all game code + scenes, one folder per system
    ├── boot/                  M1  device_check: platform smoke test / diagnostics
    ├── core/                  M4  game_manager (autoload), game states, countdown, timer
    ├── physics/               M2  rotational state + integrator (pure GDScript, no Nodes)
    ├── debris/                M2  DebrisDefinition resource, debris scene (mesh + collision)
    ├── surface/               M2  SurfaceMaterial resource (ablation efficiency)
    ├── laser/                 M2  LaserConfig, ablation impulse model, beam/spot visuals
    ├── input/                 M3  AimInput interface, joystick + motion implementations
    ├── ui/                    M4+ HUD, menus, sci-fi theme
    ├── persistence/           M5  settings store, highscore store
    └── audio/                 M5  audio manager (autoload)
(planned) data/                .tres instances: debris/envisat.tres, laser/default.tres, rules/default.tres
(planned) assets/              models/<debris>/, textures/, audio/, fonts/
(planned) tests/               headless unit tests for the physics
```

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

Planned interfaces (pure `RefCounted`, no scene dependency):

```
RotationalState        orientation q (Quaternion), angular momentum L (world, kg·m²/s),
                       body inertia tensor I_body (Basis), centre of mass
                       -> angular_velocity_world(): ω = R · I_body⁻¹ · Rᵀ · L
RotationalIntegrator   step(state, dt): torque-free motion, L constant, q advanced by ω
                       (fixed step in _physics_process, sub-stepped if needed)
                       apply_impulse(state, point_world, J_world): L += (p - c) × J
```

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

### 3. Data-driven debris and surfaces (M2, extended later)

`DebrisDefinition` (custom `Resource`, one `.tres` per object): display name, model scene, mass,
centre of mass, inertia tensor, collision shape source, default `SurfaceMaterial`, initial-spin
limits. Adding a rocket stage later = new `.tres` + model; no code changes.
Surface zones (reflective panels, fragile parts, damage) attach `SurfaceMaterial`s to collision
shapes/mesh surfaces – the hook exists from M2, the zones themselves are a future feature.

### 4. Input abstraction (M3)

```
AimInput (base)        get_aim_delta(dt) -> Vector2      // yaw/pitch rate request
 ├── JoystickAimInput  virtual joystick (left thumb), sensitivity, smoothing
 └── MotionAimInput    gravity/gyroscope, calibration (neutral pose), invert, dead-zone,
                       low-pass filter against drift
LaserAimController     integrates aim deltas into a beam direction (clamped cone)
```

The laser simulation only receives a beam direction and a focus value; it never knows which input
method produced them. The active `AimInput` is chosen from settings.

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
