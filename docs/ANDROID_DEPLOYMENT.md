# Android build and deployment

Prerequisite: the toolchain from [SETUP_WINDOWS.md](SETUP_WINDOWS.md).

## 1. Prepare the phone (once)

> **Phone Link / "Link to Windows" is not needed and does not help.** It is Microsoft's phone
> sync app and has nothing to do with `adb`. Deployment only needs *USB debugging* (below).

1. **Settings → About phone → tap *Build number* 7 times** to unlock *Developer options*
   (on Samsung: *About phone → Software information → Build number*).
2. **Settings → System → Developer options → enable *USB debugging*.**
3. Connect the phone via USB. Set the USB mode to *File transfer* if it asks.
4. On the phone, accept the **"Allow USB debugging?"** prompt (tick *Always allow from this computer*).
5. Check on the PC:
   ```powershell
   adb devices
   # List of devices attached
   # R5CT1234ABC    device          <- "device" = ready; "unauthorized" = accept the prompt
   ```
   If the list is empty, see [Phone not listed by adb](#phone-not-listed-by-adb).

### Phone not listed by `adb`

Check what Windows sees (PowerShell):

```powershell
Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -like 'USB\VID_18D1*' -or $_.FriendlyName -match 'ADB|Android' } |
    Select-Object Status, Class, FriendlyName, InstanceId
```

| What you see | Meaning / fix |
|---|---|
| Only a `WPD` device with your phone's name (e.g. *Fairphone 4 5G*, `PID_4EE1`) | USB debugging is **off** – the phone only offers file transfer. Enable it (steps 1–2), then unplug/replug |
| Additional *ADB Interface* / *Android Composite ADB Interface* (`PID_4EE2`, `4EE7`, …), status OK | Driver fine – unlock the phone and accept the *Allow USB debugging?* prompt; run `adb kill-server; adb devices` |
| An *ADB Interface* or unknown device with status **Error** | Windows has no ADB driver: download Google's driver <https://dl.google.com/android/repository/usb_driver_r13-windows.zip> (works for Pixel, Fairphone and other phones using Google's USB ID `18D1`), extract it, then *Device Manager → the device → Update driver → Browse my computer → the extracted folder* (needs admin) |
| Nothing at all | Charge-only cable or bad port – try another cable / a port directly on the PC |

Samsung and Xiaomi phones use their own manufacturer USB drivers instead of Google's.

**Wireless debugging (Android 11+, optional):** *Developer options → Wireless debugging → Pair
device with pairing code*, then `adb pair <ip>:<port>` and `adb connect <ip>:<port>`.

## 2. Deploy from the Godot editor (main workflow)

The project already contains an **Android** export preset (`export_presets.cfg`, marked *Runnable*).

1. In Godot, enable **Debug → Deploy with Remote Debug** (sends `print()` output and errors from
   the phone to the editor's *Output* / *Debugger* panels, breakpoints work).
2. With the phone connected, an **Android icon** appears in the top-right toolbar
   (*Remote Deploy*). Click it and select the device.
3. Godot exports a debug APK, installs it and launches it. The first export takes longer.

Faster iteration: **Debug → Small Deploy with Network File System** loads project files from the
PC instead of packing them into the APK (needs the phone and PC on reachable networks / USB `adb reverse`).

The debug build is signed with a **debug keystore** that Godot generates automatically on the
first export (`%APPDATA%\Godot\keystores\debug.keystore`). Nothing to configure.

## 3. Build from the command line

```powershell
# export debug APK, install it on the connected phone, launch it, stream the log
powershell -ExecutionPolicy Bypass -File tools\build_android.ps1 -Logcat

# export only
powershell -ExecutionPolicy Bypass -File tools\build_android.ps1 -NoInstall
```

The APK goes to `build/android/laser_detumbling-debug.apk` (git-ignored).
Useful `adb` commands:

```powershell
adb logcat -s godot:V                       # Godot log only
adb uninstall com.rodeogames.laserdetumbling
adb shell am force-stop com.rodeogames.laserdetumbling
```

## 4. Milestone 1 device checklist

Launch the app on the phone and confirm:

- [ ] App starts in **landscape**, fullscreen (immersive: no status/navigation bar).
- [ ] A slowly **rotating gold/blue placeholder satellite** is visible and lit.
- [ ] **Renderer** line shows `mobile` (Vulkan). `gl_compatibility` means the device has no usable
      Vulkan driver and Godot fell back to OpenGL ES 3 – note the device model.
- [ ] **FPS** is ~60 (or the display's refresh rate).
- [ ] Rotating the phone 180° flips the landscape orientation (sensor landscape).
- [ ] **Accelerometer / Gravity** values change when tilting; *Gyroscope* changes while rotating
      (shows "(no data)" on phones without a gyroscope).
- [ ] Touching shows a **red marker**; two fingers → *max 2 simultaneous* touches.
- [ ] Home button, then returning to the app → the counters on the *Lifecycle* info line read
      *paused 1 / resumed 1* (the scene keeps spinning – this screen only counts the events;
      the real pause menu comes in Milestone 4).
- [ ] **QUIT** button closes the app. Android **back** gesture also closes it.

Please report the device model, Android version, renderer line, FPS and any failed item.

## 5. Release builds (later, Milestone 6)

Release builds need your own **release keystore** (never the debug one, never committed):

```powershell
& "$env:JAVA_HOME\bin\keytool.exe" -v -genkey -keystore $env:USERPROFILE\keys\laser_detumbling.keystore `
    -alias laserdetumbling -keyalg RSA -validity 10000
```

Configure it in *Project → Export → Android → Keystore → Release / Release User / Release Password*.
Godot stores these credentials in `.godot/export_credentials.cfg` (git-ignored), not in
`export_presets.cfg`. Keystore and key password must currently be identical. **Back up the
keystore** – losing it means you can never update the app on Google Play.

Google Play requires an **AAB**, which needs a Gradle build: run the setup script with
`-WithGradleBuildTools`, then *Project → Install Android Build Template* and enable
*Gradle Build → Use Gradle Build* with export format *AAB* in the preset.

## Troubleshooting

| Symptom | Fix |
|---|---|
| No Android icon in the Godot toolbar | Preset not *Runnable*, phone not in `adb devices`, or *Android SDK Path* not set in Editor Settings |
| *"Target platform requires 'ETC2/ASTC' texture compression"* | Already enabled in `project.godot` (`rendering/textures/vram_compression/import_etc2_astc`) – re-open the project |
| *"Could not install to device"* | An app with the same package but a different signature is installed: `adb uninstall com.rodeogames.laserdetumbling` |
| *"Java SDK path invalid"* / *"apksigner not found"* | Check Editor Settings → Export → Android paths; build-tools 35.0.1 must exist |
| Export template missing | Editor → Manage Export Templates, version must be exactly 4.7.2 |
| Black screen on old device | Check renderer line / logcat; Vulkan driver issues fall back to OpenGL automatically (`rendering/rendering_device/fallback_to_opengl3`) |
