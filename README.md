# GNU BonziBuddy

GNU BonziBuddy is a free software, privacy-preserving alternative to the original BonziBuddy for macOS.

A native AppKit desktop companion with a rigged 3D fan model, Metal rendering, 4× MSAA, and real-time soft shadows. Runs locally with macOS speech; no third-party APIs, analytics, accounts, or network services.

## Build and run

Requires macOS 14+, a Metal-capable Mac, and Apple Command Line Tools. No package manager, model editor, or full Xcode installation is needed.

```sh
./Scripts/build.sh
open Build/BonziBuddy.app
```

The build produces an ad-hoc signed app with all runtime assets bundled. Drag Bonzi to move him, double-click for chat controls, or right-click for animations, facial controls, reminders, and settings. Speech uses available macOS voices. Reminders require the app to be running and persist locally.

## Current state

The default model has a 20% neutral smile, 15 facial morph controls, gaze, blinking, articulated hands, and a growing catalog of actions with interruption blending, including globe spinning, coconut juggling, butterfly interaction, seated reading, coconut headphones, initial banana routines, and independently toggleable sunglasses and headphones that stay on during other actions. The approved appearance is preserved in `References/ApprovedFanAppearance/`.

Visual likeness and animation coverage are still in progress. The latest live measurements are near **60 fps**, despite requesting 120 fps; presentation pacing remains unresolved. Reminders also need UI polish. See [current status](Docs/status.md) for limitations and recorded checks.

## Project layout

| Directory | Contents |
| --- | --- |
| `Sources/BonziBuddy/` | AppKit UI, animation, model loading, Metal renderer, shaders, and validation entry points |
| `Resources/FanModel/` | Required runtime meshes, rig, facial morphs, and attribution |
| `Scripts/` | Build, asset conversion, and validation tools |
| `References/` | Original comparison artwork, approved appearance checkpoints, and source interchange |
| `Docs/` | Architecture, asset workflow, validation instructions, and historical notes |
| `Build/`, `.build/`, `Validation/` | Ignored local output |

[Choreography architecture](Docs/choreography.md) · [Original visual repertoire](Docs/original-visual-repertoire.md) · [Architecture](Docs/architecture.md) · [Asset provenance and conversion](Docs/assets.md) · [Validation](Docs/validation.md)

The imported model is credited to YinyangGio; see [bundled attribution](Resources/FanModel/ATTRIBUTION.txt). Reference artwork belongs to its respective rights holders. This project does not grant rights to the original character.

## License

GNU BonziBuddy's original source code, scripts, and documentation are free
software under the **GNU General Public License, version 3 or (at your option)
any later version** (`GPL-3.0-or-later`). See [LICENSE](LICENSE) for the full terms
and [NOTICE.md](NOTICE.md) for scope and third-party asset attribution.

Imported fan-model assets retain their separate Creative Commons Attribution
terms. Original comparison artwork remains subject to its respective owners'
rights; it is not bundled with the app or relicensed by this project.
