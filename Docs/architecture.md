# Architecture

The app uses AppKit and MetalKit directly. `Scripts/build.sh` compiles Swift sources, bakes the legacy procedural mesh when needed, bundles assets, and ad-hoc signs the app. Metal source compiles at launch.

| Files under `Sources/BonziBuddy/` | Responsibility |
| --- | --- |
| `App.swift`, `main.swift` | Desktop panel, menus, local speech, launch flags, validation dispatch |
| `Renderer.swift`, `Shaders.metal` | Mesh buffers, skinning and morph uniforms, MSAA, lighting, shadow passes, presentation and profiling |
| `FanRig.swift`, `FanFaceMotion.swift` | Imported joint hierarchy, poses, choreography, interruption blends, automatic facial motion |
| `Animation.swift` | Action definitions, timing, reference curves, and procedural animation |
| `ExpressionControls.swift` | Native sliders for facial morphs, gaze, and eye closure |
| `Reminders.swift`, `ReminderControls.swift` | Local reminder persistence, delivery, and UI |
| `Character.swift`, `Mesh.swift` | Legacy procedural character generation and mesh formats |
| `*Validation.swift`, `FanPreview.swift`, `MeshChecks.swift` | Offline render reviews and numerical checks |

The default rigged fan model uses indexed polygon meshes, up to eight joint influences per vertex, and fifteen facial morph targets. Skinning and deformation are shared by color and shadow rendering. Bone buffers rotate through three in-flight slots. The renderer requests 120 Hz, uses 4× MSAA where supported, and filters a 2048² shadow map for soft shadows.

Runtime resources resolve inside the app bundle, so the built app works outside the checkout. Validation and research tools run from the repository root. `--procedural-model` selects the retained procedural comparison model.

Speech uses `AVSpeechSynthesizer`. Mute settings and reminders use local UserDefaults; typed speech is not stored. There are no external service integrations or installed background agents.
