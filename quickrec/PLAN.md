# QuickRec: a lock screen button that starts recording video at once

Phone: a Samsung Galaxy running One UI (Good Lock works on it). Exact model
and One UI version still to be filled in from Settings, About phone.

## 1. What was checked before planning an app

### 1a. The lock screen rule on One UI

Samsung lets you assign almost any installed app to the two lock screen
shortcuts (Settings, Lock screen and AOD, Shortcuts). Every app except the
Camera is marked "Unlock required": tapping it first asks for the fingerprint,
face or PIN, and only then opens the app. The Camera is special because the
system launches it in a secure mode on top of the lock screen. No setting
lets another app skip the unlock, and an app cannot grant that to itself.

Consequence: whatever app is put on the second button, the sequence is tap,
unlock, app. Only the Samsung Camera can start without unlocking.

### 1b. What the Samsung Camera itself can do

Two settings in the Samsung Camera app come close to the goal with nothing
installed:

1. Camera, Settings, **Settings to keep**, **Camera mode: On**. The camera
   then reopens in the mode used last. Leave it in Video mode and the lock
   screen Camera button, and the Side button double press, open straight into
   Video mode, no unlock.
2. Camera, Settings, **Shooting methods**, **Press Volume buttons to: Record
   video**. One press of a volume key starts recording, a second press stops.

Result: tap the Camera button (or double press the Side button), press a
volume key. Recording starts in about a second, without unlocking, with
Samsung's own quality and stabilisation. No app, nothing to maintain.

There is no Samsung setting, and nothing in the Good Lock Camera Assistant
module, that starts recording on launch by itself.

Voice is a further built-in option: hold the Side button for Bixby and say
"record a video". Bixby starts the recording in the Samsung Camera.

### 1c. Existing apps that record on launch

Google Play has a category of "background video recorder" apps that start
recording the moment they open, some also from a widget or with the volume
keys. They are mostly ad supported, request broad permissions, and are built
for covert recording, so I do not recommend one without testing it. On the
lock screen they are still subject to the unlock rule above.

Open Camera, the open source camera app, could not be checked from this
environment; its help page was unreachable. It is worth a look in its
settings for a "start in video mode" or widget option before writing code.

### 1d. Verdict

The reasonable option exists and needs no app: Section 1b. If the single
remaining step, the volume press, is still one step too many, the app below
removes it, at the price of the unlock that One UI imposes on every
non-Camera app. On a phone with face unlock the unlock is nearly invisible;
with a fingerprint it is one touch.

## 2. The app, if wanted

### Behaviour

- Launch equals record. The only activity binds the camera and starts
  recording as soon as the camera is ready, typically under a second on a
  recent Galaxy. No splash screen, no menu, no confirmation.
- Screen while recording: live preview, red dot with elapsed time, one large
  Stop button. Volume keys and the Back button also stop. Stopping finalises
  the file and shows a small "Saved" message; a second tap opens the Gallery.
- Files go to DCIM/QuickRec through MediaStore, so they appear in Gallery and
  Google Photos at once and survive uninstalling the app. Names carry the
  timestamp.
- Safety limits: auto stop at a configurable length (default 10 minutes), at
  low battery, and when storage runs out, each with a clear message. Leaving
  the app (screen off, call, home) stops and saves rather than recording
  blind.
- Settings screen, reached from a small gear on the recording screen or from
  the launcher: rear or front camera, resolution (FHD default, UHD optional),
  audio on or off, auto stop length, torch on start. Settings are the only
  place where permissions are requested, so the record screen never pauses
  for a prompt after first use.
- Launch surfaces: the One UI lock screen shortcut, the Side button double
  press set to "Open app", the home screen icon, and a static app shortcut
  "Record with front camera".

### Architecture

```
app/src/main/java/.../quickrec/
  RecordActivity.kt     the whole fast path: bind camera, start recording,
                        timer, stop handling; plain Views for minimal startup
  CameraController.kt   CameraX Preview + VideoCapture<Recorder>, quality
                        selection with fallback, output options, events
  Limits.kt             auto stop timer, battery and storage watchers
  SettingsActivity.kt   permissions flow and the few options (DataStore)
  res/layout/activity_record.xml
```

CameraX (Jetpack) is the deliberate choice over the raw Camera2 API: it is
Google's compatibility layer across makers and Android versions, which is
what makes the app survive phone upgrades. Only public APIs, no Samsung
camera SDK, no reflection.

Core of the fast path:

```kotlin
override fun onCreate(state: Bundle?) {
    super.onCreate(state)
    setShowWhenLocked(true); setTurnScreenOn(true)
    window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    setContentView(binding.root)
    if (!hasPermissions()) { startActivity(Intent(this, SettingsActivity::class.java)); finish(); return }
    cameraController.start(this, binding.preview) { recorder ->
        recording = recorder.prepareRecording(this, outputOptions())
            .apply { if (settings.audio) withAudioEnabled() }
            .start(mainExecutor, ::onRecordEvent)
    }
}
```

Quality selection: FHD with `FallbackStrategy.higherQualityOrLowerThan`, so
any phone, present or future, gets the best it supports without code
changes.

### Permissions and manifest

| Permission | Why |
| --- | --- |
| `CAMERA` | recording |
| `RECORD_AUDIO` | sound track; the app works without it if the user declines, recording silent video |

No storage permission: MediaStore inserts of the app's own files need none
on Android 10 and later. No foreground service, no background work, no
network. `minSdk 29`, `targetSdk` the latest stable.

### What keeps it generic

1. CameraX with fallback strategies instead of device-specific profiles.
2. One activity, one fast path, every option off by default.
3. Public APIs only; no lock screen tricks, since One UI decides the unlock
   rule and the app only has to be launchable.
4. Target the latest Android on each build; the only recently changed rules
   that touch this app are the storage rules, already handled by MediaStore.

### Tests on the phone

| Test | Expected |
| --- | --- |
| Time from tap to recording, read from logcat timestamps | under 1 s warm, under 2 s cold |
| Lock screen shortcut with fingerprint, then with face unlock | recording starts right after unlock |
| Side button double press set to the app | same |
| Incoming call during recording | file saved up to the interruption |
| Side button pressed to turn the screen off | file saved |
| Storage nearly full | clean stop with message, file playable |
| Auto stop at the limit | file playable, correct length |
| Rotation during recording | file plays with the right orientation |
| Front camera shortcut | front camera, mirrored preview, correct file |
| Uninstall and reinstall | earlier videos still in Gallery |

### Milestones

1. Record on launch with a Stop button, file in DCIM, tested on the phone.
2. Volume keys, timer, auto stop, battery and storage limits.
3. Settings screen with permissions and options, front camera shortcut.
4. Lock screen and Side button setup, full test table, signed build over ADB.

## 3. Decisions for you

- Try Section 1b first. If "Settings to keep, Camera mode" does not apply to
  the lock screen camera on your One UI version, tell me what happens.
- If you still want the app: face unlock or fingerprint on the phone? It
  decides how invisible the unlock step is.
- Default rear camera at FHD, 10 minute auto stop, audio on: fine as
  defaults?
