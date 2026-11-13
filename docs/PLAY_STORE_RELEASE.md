# Publishing on Google Play

Google Play only accepts **Android App Bundles (`.aab`)** for new apps – not APKs. Play builds
optimised APKs per device from the bundle. The signed release **APK** is for sharing directly
(e-mail, website, sideloading); it is not uploaded to Play.

| File | Use |
|---|---|
| `build/android/laser_detumbling-release.aab` | Upload to the Play Console |
| `build/android/laser_detumbling-release.apk` | Share directly; recipients must allow "Install unknown apps" |
| `build/store/icon_512.png` | Store listing icon (generated, see below) |

## 1. Build

```powershell
# once: Gradle build requirements (Android 36, build-tools 36.1.0, NDK 29)
powershell -ExecutionPolicy Bypass -File tools\setup_windows.ps1 -WithGradleBuildTools
# once: release (upload) key -> %USERPROFILE%\.laser-detumbling\   BACK IT UP
powershell -ExecutionPolicy Bypass -File tools\create_release_keystore.ps1

powershell -ExecutionPolicy Bypass -File tools\build_android.ps1 -Release -Aab   # for Play
powershell -ExecutionPolicy Bypass -File tools\build_android.ps1 -Release        # APK to share
```

**Before every new upload, increase `version/code`** (and usually `application/config/version`)
in `export_presets.cfg` / `project.godot` – Play rejects a bundle whose version code it has seen.
The package name `com.rodeogames.laserdetumbling` is permanent once the app exists on Play.

## 2. Play Console (one-time)

1. Create a developer account at <https://play.google.com/console> (one-time fee, identity
   verification). Personal accounts created after Nov 2023 must run a **closed test with at least
   12 testers for 14 days** before they can publish to production – check the current rule in the
   Console.
2. **Create app**: name "Laser De-Tumbling", default language, *Game*, *Free*.
3. **Play App Signing**: accept the default (Google manages the app-signing key). The key in
   `%USERPROFILE%\.laser-detumbling\` becomes your *upload key*.

## 3. App content (Policy section)

| Item | Answer for this game |
|---|---|
| Privacy policy | A simple public page stating that the app collects no data (highscores and settings stay on the device) |
| Ads | No ads |
| App access | All functionality available without login |
| Content rating | Fill in the questionnaire (no violence, no user content) – expect "Everyone"/PEGI 3 |
| Target audience | e.g. 13+ (choosing under-13 triggers the Families policy requirements) |
| Data safety | No data collected, no data shared |
| Government apps / financial / health | No |

## 4. Store listing

- Short description (≤ 80 characters), full description (≤ 4000)
- App icon **512 × 512 PNG**: `build/store/icon_512.png`
- Feature graphic **1024 × 500** (required): e.g. a gameplay screenshot with the title
- At least 2 phone screenshots (take them on the phone: power + volume-down) – landscape is fine
- Category *Simulation* or *Arcade*; contact e-mail

## 5. Upload and roll out

1. *Testing → Internal testing → Create release* → upload the `.aab` → add release notes → roll out.
2. Add testers (e-mail list), share the opt-in link, install via Play on a phone.
3. Then *Closed testing* (12 testers / 14 days for new personal accounts) → *Production*.

Play's pre-launch report runs the game on test devices – check it for crashes before production.

## Notes

- Target API: Godot 4.7.2 builds with target SDK 36, which satisfies Play's current target-API
  requirement for new apps. Re-check when Play raises it (usually every August).
- 64-bit: the AAB contains arm64-v8a (required) and armeabi-v7a (older 32-bit phones).
- Installing a release build on a phone that has the debug build fails ("signatures don't
  match"): uninstall the debug app first (this deletes its local highscores and settings).
