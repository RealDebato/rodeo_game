# Development environment setup (Windows 11 + VS Code)

This guide sets up everything needed to edit, run and deploy the game to an Android phone.
Everything installs **per user** – no administrator rights are needed.

| Component | Version | Purpose |
|---|---|---|
| Git | any recent | Version control |
| Visual Studio Code | any recent | Primary script editor |
| VS Code extension **godot-tools** (`geequlim.godot-tools`) | latest | GDScript language server, syntax, debugger |
| **Godot Engine 4.7.2** – *standard* build (not .NET) | 4.7.2-stable | Scenes, assets, rendering, running, exporting |
| Godot **export templates** | 4.7.2 (must match the editor exactly) | Prebuilt Android/iOS runtimes |
| **OpenJDK 17** (Eclipse Temurin) | 17.x | Signing and building Android packages |
| Android SDK **cmdline-tools** | latest (2026: includes the new `android` CLI) | SDK package management |
| Android SDK **platform-tools** | ≥ 35 | `adb` – install/launch/debug on device |
| Android SDK **build-tools** | 35.0.1 | `apksigner`, `zipalign` |
| Android SDK **platform** | android-35 | Target API |
| *(optional)* NDK r28b + CMake 3.10.2 | 28.1.13356709 / 3.10.2.4988404 | Only for Gradle builds (Android plugins, AAB) |

> **Why the standard build and not Godot .NET?** The project uses GDScript. The .NET build is
> larger, and C# export to Android/iOS is still marked experimental in Godot 4.7.

---

## Option A – automated (recommended)

From the repository root in PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File tools\setup_windows.ps1
```

The script is idempotent (safe to re-run) and performs every step from Option B. It asks you to
accept the Android SDK license (<https://developer.android.com/studio/terms>); pass
`-AcceptAndroidLicenses` to accept non-interactively. Add `-WithGradleBuildTools` only when you
need Gradle builds.

Afterwards:

1. **Open a new terminal and fully restart VS Code** – close *all* VS Code windows, otherwise
   VS Code keeps the old environment and `${env:GODOT}` is empty.
2. Continue with [Verify the installation](#verify-the-installation).

---

## Option B – manual installation

### 1. Git and VS Code
Install from <https://git-scm.com> and <https://code.visualstudio.com> (or
`winget install Git.Git Microsoft.VisualStudioCode`).

Install the Godot extension:
```powershell
code --install-extension geequlim.godot-tools
```
Opening this repository in VS Code also offers it automatically (`.vscode/extensions.json`).

### 2. Godot 4.7.2
```powershell
winget install --id GodotEngine.GodotEngine --version 4.7.2 --exact
```
or download *Godot Engine – Windows x86_64* from <https://godotengine.org/download/windows/> and
unzip it anywhere (e.g. `%LOCALAPPDATA%\Programs\Godot`). Godot is portable; there is no installer.

The zip contains two executables: `Godot_v4.7.2-stable_win64.exe` (editor) and
`..._console.exe` (same, but keeps a console window – use this one for command-line builds).
Set a user environment variable `GODOT` to the **console** executable; `tools\build_android.ps1`
uses it.

### 3. OpenJDK 17
Download the *Temurin 17 JDK* (zip or msi) from <https://adoptium.net/temurin/releases/?version=17>,
then set the user environment variable `JAVA_HOME` to the JDK folder (the one containing `bin\java.exe`).
Godot 4.7 supports newer JDKs, but 17 is the version Godot recommends and tests against.

### 4. Android SDK

**Command line (lightweight, ~0.5 GB):**
1. Download *Command line tools only – Windows* from <https://developer.android.com/studio#command-tools>.
2. Extract it so that the path is `%LOCALAPPDATA%\Android\Sdk\cmdline-tools\latest\bin\android.exe`
   (the zip contains a `cmdline-tools` folder – rename it to `latest`).
3. Install the packages:
   ```powershell
   $sdk = "$env:LOCALAPPDATA\Android\Sdk"
   & "$sdk\cmdline-tools\latest\bin\android.exe" --no-metrics --sdk=$sdk sdk install platform-tools build-tools/35.0.1 platforms/android-35
   ```
   > Since 2026 the old `sdkmanager` is deprecated and replaced by `android sdk`. Package names
   > use `/` instead of `;`. **Unknown package names are silently ignored** – check that the
   > folders `build-tools\35.0.1`, `platforms\android-35` and `platform-tools` exist afterwards.
   > `--no-metrics` disables Google's usage telemetry for the CLI.
4. Set the user environment variable `ANDROID_HOME` to `%LOCALAPPDATA%\Android\Sdk` and add
   `%LOCALAPPDATA%\Android\Sdk\platform-tools` to your user `Path`.

**Alternative – Android Studio (~3 GB):** install Android Studio, open *SDK Manager* and install
*SDK Platform 35*, *Build-Tools 35.0.1*, *Platform-Tools* and *Command-line Tools (latest)*.
This is useful if you later need emulators or Android profiling tools.

### 5. Export templates
Start Godot → open this project → **Editor → Manage Export Templates… → Download and Install**.

Manual alternative: download `Godot_v4.7.2-stable_export_templates.tpz` from the
[GitHub release](https://github.com/godotengine/godot/releases/tag/4.7.2-stable), and extract the
contents of its `templates` folder to `%APPDATA%\Godot\export_templates\4.7.2.stable\`.

### 6. Godot editor settings
**Editor → Editor Settings…** (these are per-user, stored in `%APPDATA%\Godot\editor_settings-4.7.tres`):

| Setting | Value |
|---|---|
| Export → Android → **Java SDK Path** | your `JAVA_HOME` folder |
| Export → Android → **Android SDK Path** | `%LOCALAPPDATA%\Android\Sdk` (must contain `platform-tools\adb.exe`) |
| Text Editor → External → **Use External Editor** | On |
| Text Editor → External → **Exec Path** | `C:\Program Files\Microsoft VS Code\Code.exe` (or `%LOCALAPPDATA%\Programs\Microsoft VS Code\Code.exe`) |
| Text Editor → External → **Exec Flags** | `{project} --goto {file}:{line}:{col}` |
| Network → Language Server → Remote Port | `6005` (Godot default; `.vscode/settings.json` points godot-tools here) |
| Network → Debug Adapter → Remote Port | `6006` (default) |

With *Use External Editor* on, double-clicking a script in Godot opens it in VS Code.

### 7. VS Code settings
Nothing to do – `.vscode/settings.json` is committed with the repository and contains:

- `"godotTools.editorPath.godot4": "${env:GODOT}"` – uses the `GODOT` environment variable, so no
  machine-specific path is committed. (Manual install: set `GODOT` yourself, then restart VS Code.)
- `"godotTools.lsp.serverPort": 6005` – **godot-tools defaults to 6008, but the Godot 4.7 editor
  serves the language server on 6005.** Without this you get *"Couldn't connect to the GDScript
  language server at 127.0.0.1:6008"*.
- Tabs for GDScript, LF line endings, hidden `.godot` cache.

**The language server runs inside the Godot editor.** Open the project in Godot first
(`godot --editor --path .`), then VS Code connects automatically (status bar: *Godot LSP connected*).
If you want completion without the editor open, set `"godotTools.lsp.headless": true` in your
*user* settings: godot-tools then starts its own headless Godot in the background. Don't use that
while the editor is also open on the same port.

---

## Verify the installation

In a **new** PowerShell window:

```powershell
godot --version                          # 4.7.2.stable.official...
& "$env:JAVA_HOME\bin\java.exe" -version # openjdk version "17..."
adb version                              # Android Debug Bridge ...
Test-Path "$env:APPDATA\Godot\export_templates\4.7.2.stable\android_debug.apk"   # True
```

Then:

1. Open the project in Godot: `godot --editor --path .` (or *Import* `project.godot` in the
   Project Manager). The first open imports assets and creates the `.godot/` cache.
2. Press **F5** in Godot – the *Device Check* scene opens in a 1600×720 window (phone-like 20:9).
3. **With the Godot editor still open**, open the folder in VS Code and open
   `src/boot/device_check.gd`: the status bar should show the Godot language server as
   **connected**. If not: run *Godot Tools: Open workspace with Godot editor* or check the port
   (step 7).
4. In VS Code press **F5** (*Godot: Launch project*) – the game starts and breakpoints in `.gd`
   files work.

Then continue with [ANDROID_DEPLOYMENT.md](ANDROID_DEPLOYMENT.md).

## Day-to-day workflow

- **Godot editor** stays open: scenes, inspector, import, running (F5/F6), one-click deploy.
- **VS Code** for all scripting: completion and errors via the Godot language server, debugging
  with F5. Godot hot-reloads saved scripts.
- **Git** from VS Code or the terminal. Commit `.tscn`, `.tres`, `.gd`, **`.uid`** and `.import`
  files; never commit `.godot/`, `build/` or keystores.
