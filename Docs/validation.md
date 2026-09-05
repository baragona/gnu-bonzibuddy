# Validation

Run commands from the repository root after `./Scripts/build.sh`. Generated output goes into the ignored `Validation/` directory. GPU checks need access to a macOS graphical session and Metal device.

## Quick checks

```sh
python3 Scripts/check-fan-export.py
python3 Scripts/check-fan-mesh.py
Build/BonziBuddy.app/Contents/MacOS/BonziBuddy --validate-reminders
Build/BonziBuddy.app/Contents/MacOS/BonziBuddy --validate-fan-contacts
```

## Animation and facial review

```sh
Build/BonziBuddy.app/Contents/MacOS/BonziBuddy --validate-fan-actions
Build/BonziBuddy.app/Contents/MacOS/BonziBuddy --validate-fan-transitions
Build/BonziBuddy.app/Contents/MacOS/BonziBuddy --validate-fan-wave
Build/BonziBuddy.app/Contents/MacOS/BonziBuddy --validate-fan-actions --face-only
```

Action GIFs show full sequences from front, three-quarter, and left views. Inspect pose silhouettes, wrist motion, foot placement, contact, facial expression, and transition continuity. Preview playback is 15 or 30 fps; it does not establish application frame rate.

`--preview-fan` additionally compares baked facial endpoints and source bind pose. First generate its ignored endpoint assets using `python3 Scripts/build-fan-morphs.py`.

## Live performance

```sh
Build/BonziBuddy.app/Contents/MacOS/BonziBuddy --onscreen-validation
```

Quit other Bonzi instances before measuring. The separate benchmark runs for about twelve seconds, cycles actions, and exits. Inspect actual drawable presentation timestamps in `Validation/FanRigged/onscreen-performance.json`, alongside CPU and GPU stage times. Requested refresh rate and offscreen GPU timings alone do not establish smooth 120 fps. See [status](status.md) for the unresolved pacing issue.

## Legacy comparisons

`Scripts/validate.sh` runs the earlier procedural renderer and original-sprite comparison. It is retained for research and is not the default fan-model validation suite. The likeness gate remains unmet; a failing comparison must not be reported as a successful identity match.
