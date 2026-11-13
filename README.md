# Laser De-Tumbling

A mobile 3D game about laser-ablative de-tumbling of space debris. You control a laser on a
servicer satellite and must stop a tumbling object – starting with ESA's **Envisat** – as fast as
possible. Every laser shot creates an ablation recoil impulse **J** at the hit point; its angular
impulse **ΔL = r × J** decides whether the tumble slows down or speeds up.

- Engine: Godot 4.7.2 (GDScript), Mobile renderer
- Platforms: Android (now), iOS (later)
- Editor: VS Code + godot-tools

## Quick start

```powershell
# 1. install toolchain (Godot, JDK 17, Android SDK, export templates, VS Code extension)
powershell -ExecutionPolicy Bypass -File tools\setup_windows.ps1

# 2. open a new terminal, then open the project in Godot
godot --editor --path .

# 3. build + install + launch on a USB-connected phone
powershell -ExecutionPolicy Bypass -File tools\build_android.ps1 -Logcat
```

## Documentation

- [docs/SETUP_WINDOWS.md](docs/SETUP_WINDOWS.md) – development environment (automated and manual)
- [docs/ANDROID_DEPLOYMENT.md](docs/ANDROID_DEPLOYMENT.md) – phone setup, one-click deploy, CLI builds, release signing
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) – project structure and technical decisions

## Roadmap

| Milestone | Content | Status |
|---|---|---|
| 1 | Development environment, Android deployment | **done** – verified on Fairphone 4 5G |
| 2 | 3D simulation prototype: Envisat model, rotational physics, laser raycast, recoil torque | **done** |
| 3 | Player interaction: joystick + motion aiming, firing, impact visualisation (+ main menu, options, credits, highscore storage pulled in from M5) | **implemented** – device test pending |
| 4 | Game loop: countdown, completion threshold, timer, pause/restart | – |
| 5 | Menus and persistence: main menu, highscores, options, credits, exit | – |
| 6 | Mobile optimisation, real-device testing, iOS preparation | – |

## License

MIT – see [LICENSE](LICENSE). Third-party assets will be listed in the in-game credits and here.
