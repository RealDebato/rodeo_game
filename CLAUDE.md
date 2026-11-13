# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Project

**Laser De-Tumbling** – mobile 3D game (Godot 4.7.2, GDScript). The player aims a laser from a
servicer satellite at a tumbling debris object (first: ESA Envisat). Ablation recoil impulses
create torque about the centre of mass; the goal is to bring the rotation to a near stop as fast as
possible. Target: Android now, iOS later. Landscape only.

The full product brief lives in the first conversation; the condensed design is in
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). Read it before adding a new system.

## Current status

- **Milestone 1 (environment) – complete, verified 2026-11-13 on Fairphone 4 5G** (Android 13,
  Adreno 619, Vulkan/Mobile renderer, 2340×1080): rendering, landscape flip, multi-touch,
  accelerometer/gravity/gyroscope, pause/resume notifications, quit/back all OK.
  `src/boot/device_check.tscn` remains as diagnostics scene (run it with F6).
- Godot 4.7 sensors are opt-in: `input_devices/sensors/enable_accelerometer|gravity|gyroscope`
  are enabled in `project.godot` (magnetometer deliberately off). Without them the values are zero.
- **Milestone 2 (simulation prototype) – done**, verified on the Fairphone. Envisat is a
  primitive placeholder (no suitably licensed Envisat model found).
- **Milestone 4 (game loop) – implemented, 43 unit tests pass, awaiting device test.**
  Rules in `data/rules/default_rules.tres` (user decisions): start always 45 °/s, only the
  direction of L random, fixed start orientation; win = |ω| < 4 °/s held 1 s; 3 s countdown
  (debris tumbles, laser + timer start at GO). Gain 500. FIRE: hold, or double-tap = continuous
  wave (CW) toggle. Tilt mode puts FOCUS on the left. Pause menu (resume/restart/menu),
  auto-pause on app pause / focus loss, Android back = pause. Win screen with time + highscore
  place. HUD still shows only spin rate + change (user's choice: no timer while playing).
- **Servicer orbit (important):** recoil can hardly create torque about the laser's line of sight,
  so with a fixed viewpoint the L component along it was unreachable (bot got stuck at 12–16 °/s).
  The servicer (camera + laser, node `Servicer`) now circles the debris at 5 °/s
  (`GameRules.servicer_orbit_deg_s`). A greedy "perfect player" bot then wins in 1:17–4:03.
- Milestone 3 (player interaction) – done; details:
  At the user's request it also pulled in parts of M5: main menu (START / HIGHSCORES / OPTIONS /
  CREDITS / QUIT, main scene `src/ui/main_menu.tscn`), options with persistence, highscore storage
  (no entries until M4 adds completion), credits. HUD shows only spin rate + laser-induced spin
  change, plus a red/green border glow (red = speeding up, green = slowing).
  Sound/music volume options are deferred until audio exists.
- Next: Milestone 5 leftovers (audio + volume options) and Milestone 6 (device optimisation,
  iOS preparation). Balancing of session length may be revisited (see README).
- Work milestone by milestone. **Do not implement future-milestone features early**
  (surface zones, damage, multiple debris models, online leaderboards are explicitly *later*), but
  keep the hooks described in ARCHITECTURE.md.
- After each milestone: explain what was implemented, how to test it, what remains; update the
  roadmap table in README.md and the status section here.

## Commands (PowerShell, repo root)

```powershell
godot --editor --path .                               # open editor (godot = shim from setup script)
godot --headless --path . --import                    # import/check project; fails on broken resources
godot --headless --path . --quit-after 180            # run main scene ~3 s headless; watch for SCRIPT ERROR
godot --headless --path . --check-only --script res://src/x/y.gd   # parse-check one script
godot --headless --path . -s res://tests/run_tests.gd # unit tests; exit code = failed count
powershell -ExecutionPolicy Bypass -File tools\build_android.ps1 -NoInstall   # export debug APK
powershell -ExecutionPolicy Bypass -File tools\build_android.ps1 -Logcat      # export + install + run + log
powershell -ExecutionPolicy Bypass -File tools\build_android.ps1 -Release -Aab # signed Play bundle (Gradle)
powershell -ExecutionPolicy Bypass -File tools\build_android.ps1 -Release      # signed shareable APK
godot --headless --path . -s res://tools/export_store_icon.gd                  # build/store/icon_512.png
adb logcat -s godot:V                                 # device log
```

`$env:GODOT` points to the *console* Godot exe; `godot` on PATH is a `.cmd` shim to it
(`%LOCALAPPDATA%\Programs\GodotShim`). In shells started before setup, read it with
`[Environment]::GetEnvironmentVariable('GODOT','User')`.

After changing any `.gd`/`.tscn`/`.tres`, run the headless import + run commands above and make
sure there are no errors or warnings before reporting success. Physics changes need unit tests
in `tests/test_*.gd` (extend `TestCase`, methods `test_*`); run the test command above.

Testing gotchas:
- Injected input events (`Input.parse_input_event`) are in *window* coordinates and get the
  stretch transform applied; convert with `root.get_final_transform() * viewport_pos`. The
  headless window is tiny, so unconverted positions end up ~20× off.
- Scripts run with `-s` from outside the project treat warnings as errors too (Variant inference).
- Moved collision bodies reach the physics server one tick later (first frame after spawn).
- `--fixed-fps 60` with `-s` runs simulated time as fast as possible: a scratch bot that sets
  `game._aim_angles` and presses the `fire` action plays a full mission in seconds. It writes to
  the real desktop highscore file (`%APPDATA%\Godot\app_userdata\Laser De-Tumbling\`) – back it
  up / remove it around such runs.
- In tests, sum time steps that are exact in binary (0.125) to avoid off-by-one-tick results.
- Godot 4.7 has a native `VirtualJoystick` class – a `class_name` that collides with a native
  class is a parse error ("hides a native class"). Our joystick is `TouchJoystick`.
- `inference_on_variant` is an error by default: never use `:=` on Variant values
  (Dictionary access, `Callable.call()`, `ConfigFile.get_value()`); declare the type.

Input notes:
- Regular Buttons only work for the first finger (emulated mouse). Anything that must be used
  while another finger is down (fire, focus, joystick) extends `MultiTouchControl`.
- Godot reports gravity in screen axes (x right, y up, z out of screen, pointing down). Tilt
  aiming: roll right -> gravity +x -> aim right; top edge towards player -> gravity +z -> aim up.
  Sign conventions are unit-tested in `tests/test_aim.gd`; verify on the device if changed.

## Toolchain facts (verified 2026-11-13)

- Godot 4.7.2 standard build via winget (`GodotEngine.GodotEngine`), no `godot` alias by default.
- JDK: Temurin 17 in `%LOCALAPPDATA%\Programs\Temurin\jdk-17.*` (`JAVA_HOME`).
- Android SDK: `%LOCALAPPDATA%\Android\Sdk` (`ANDROID_HOME`): platform-tools, build-tools 35.0.1,
  platforms android-35. Godot 4.7 targets SDK 36 and prints "Could not find version of build tools
  that matches Target SDK, using 35.0.1" – harmless for template (non-Gradle) exports.
- `sdkmanager` is deprecated; use `android --no-metrics --sdk=<sdk> sdk install build-tools/35.0.1`
  (slash syntax). Unknown package names are **silently ignored with exit code 0** – verify folders.
- Always pass `--no-metrics` to the `android` CLI.
- Editor settings: `%APPDATA%\Godot\editor_settings-4.7.tres` (SDK paths, VS Code as external editor).
- godot-tools 2.7 defaults to LSP port 6008, Godot 4.7 editor serves 6005 → workspace setting
  `godotTools.lsp.serverPort: 6005`. Godot path via `${env:GODOT}` (needs full VS Code restart).
- Test device: Fairphone 4 5G (USB VID 18D1; `PID_4EE1` = MTP only = USB debugging off).
  Phone Link is irrelevant for adb. The new `android` CLI does not offer the Google USB driver;
  direct download: `usb_driver_r13-windows.zip`.
- Debug keystore auto-generated at `%APPDATA%\Godot\keystores\debug.keystore`.
- Release/upload key: `%USERPROFILE%\.laser-detumbling\release.keystore` + `release.properties`
  (alias `upload`, PKCS12, SHA-256 `11:4B:C8:FD:…:01:36`). Never read or print the password; never
  copy it into the repo. Parse the properties file line by line (ConvertFrom-StringData breaks
  on Windows backslashes).
- Gradle (AAB) builds need what Godot's template declares in `android_source.zip/config.gradle`:
  compileSdk/targetSdk 36, build-tools 36.1.0, NDK 29.0.14206865 (newer than the Godot docs say).
- Google Play needs an AAB; every upload needs a higher `version/code` in `export_presets.cfg`.
- Windows PowerShell 5.1: native stderr becomes errors under `$ErrorActionPreference='Stop'` – wrap
  native calls (see `Invoke-Native` in `tools/*.ps1`). Piping input into `.bat` tools does not work.

## Architecture rules

- **Physics is the foundation and is separate from presentation and input.** Physics classes in
  `src/physics/` are `RefCounted`/`Resource`, never `Node`, never touch the scene tree, rendering or
  input, and are unit-testable headlessly.
- Rotational dynamics are our own integrator (angular momentum + full inertia tensor + quaternion
  orientation, fixed time step in `_physics_process`). **Do not use `RigidBody3D`** for the debris.
  Godot physics is used only for ray queries against the debris collision shape.
- Laser effect must come from physics: J along −surface normal, ΔL = r × J. Never add a gameplay
  shortcut that just reduces angular velocity.
- SI units internally (m, kg, s, N, W). Session length is tuned by a documented gameplay gain on
  the momentum-coupling coefficient, not by breaking the physics.
- All tunables in custom `Resource`s (`.tres` under `data/`) or settings – no magic numbers in logic.
- Input methods implement a common `AimInput` interface; the laser never knows which is active.
- One system per folder in `src/<system>/` (scene and script side by side). Autoloads only for
  app-wide services (GameManager, Settings, Highscores, AudioManager). Communicate via signals.
- No third-party addons/dependencies without explicit approval.
- Mobile first: watch draw calls, avoid per-frame allocations in hot paths, avoid real-time shadows
  on many lights, keep collision shapes simple (convex/compound, not trimesh, where possible).
- Platform specifics only via `OS.has_feature("android"|"ios"|"mobile")` in one place; no
  Android-only APIs in game code (iOS later). Respect the display safe area in UI.

## Code conventions

- GDScript with **static typing everywhere** (`untyped_declaration` warning is enabled). Use
  `:=` only when the type is obvious.
- Tabs for indentation, LF line endings (`.editorconfig`, `.gitattributes`).
- `snake_case` files/functions/variables, `PascalCase` `class_name`s and nodes, `UPPER_SNAKE` consts.
  Private members prefixed `_`. Signals in past tense (`debris_stabilized`).
- `##` doc comments on every script (purpose, what it depends on) and on public functions.
- Prefer `@export` + resources over hard-coded values; prefer signals over `get_node` across systems.
- Write `.tscn`/`.tres` by hand only for simple scenes; omit `uid=` (Godot adds it). Godot
  generates `*.gd.uid` files – **commit them** together with `.import` files.

## Files and Git

- Commit: `project.godot`, `export_presets.cfg` (contains no secrets), `.tscn`, `.tres`, `.gd`,
  `.uid`, `.import`, assets, docs.
- Never commit: `.godot/`, `build/`, `/android/` (Gradle template), `*.keystore`, `*.jks`.
  Signing passwords live in `.godot/export_credentials.cfg`.
- Package name `com.rodeogames.laserdetumbling` is used in `export_presets.cfg` and
  `tools/build_android.ps1` – change both together, and never after a store release.
- Pinned versions appear in `tools/setup_windows.ps1`, `docs/SETUP_WINDOWS.md` and this file –
  update all three when upgrading Godot or the SDK.
