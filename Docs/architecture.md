# Architecture

The app uses AppKit and MetalKit directly. `Scripts/build.sh` compiles Swift sources, bakes the legacy procedural mesh when needed, bundles assets, and ad-hoc signs the app. Metal source compiles at launch.

| Files under `Sources/BonziBuddy/` | Responsibility |
| --- | --- |
| `App.swift`, `main.swift` | Desktop panel, menus, local speech, launch flags, validation dispatch |
| `Renderer.swift`, `Shaders.metal` | Mesh buffers, skinning and morph uniforms, MSAA, lighting, shadow passes, presentation and profiling |
| `FanRig.swift`, `FanFaceMotion.swift` | Imported joint hierarchy, poses, choreography, interruption blends, automatic facial motion |
| `ActionPlayback.swift`, `Routines.swift`, `PropScene.swift`, `PropRenderer.swift` | Playback snapshots, routine intentions, prop lifecycle, semantic attachment, and polygon rendering |
| `Action.swift`, `Animation.swift` | Action catalog, legacy timing/reference curves, and procedural animation |
| `ExpressionControls.swift` | Native sliders for facial morphs, gaze, and eye closure |
| `Reminders.swift`, `ReminderControls.swift` | Local reminder persistence, delivery, and UI |
| `Character.swift`, `Mesh.swift` | Legacy procedural character generation and mesh formats |
| `*Validation.swift`, `FanPreview.swift`, `MeshChecks.swift` | Offline render reviews and numerical checks |

The default rigged fan model uses indexed polygon meshes, up to eight joint influences per vertex, and fifteen facial morph targets. Skinning and deformation are shared by color and shadow rendering. Bone buffers rotate through three in-flight slots. The renderer requests 120 Hz, uses 4× MSAA where supported, and filters a 2048² shadow map for soft shadows.

Runtime resources resolve inside the app bundle, so the built app works outside the checkout. Validation and research tools run from the repository root. `--procedural-model` selects the retained procedural comparison model.

Speech uses `AVSpeechSynthesizer`. Mute settings and reminders use local UserDefaults; typed speech is not stored. There are no external service integrations or installed background agents.

## Routine and prop boundaries

New routines use one registered `RoutineDefinition` for duration, facing policy, and a deterministic pose sampler. `GlobeRoutine`, `CoconutJuggle`, the two `BananaRoutine` variants, `SunglassesRoutine`, `HeadphonesRoutine`, `ButterflyRoutine`, and `ReadRoutine` exercise this path. The older ten actions still contain legacy rig-specific curves; moving those curves into routine samplers remains work.

```mermaid
flowchart TD
    Input[App action request] --> Playback[ActionPlayback: selection and time]
    Playback --> Snapshot[Read-only ActionSnapshot]
    Snapshot --> Definition[RoutineDefinition: sample elapsed time]
    Definition --> Pose[RoutinePose]
    Pose --> Rig[FanRig: IK and skeletal blend]
    Pose --> Face[FanFaceMotion: facial channel blend]
    Pose --> Props[PropMotion: attachments and interruption state]
    Rig --> Props
    Face --> Overrides[Apply user expression controls]
    Props --> GPU[PropRenderer: buffers and materials]
    Overrides --> Render[Renderer]
    GPU --> Render
    Render --> Passes[Shared deformation, color and shadow passes]
```

- **Playback owns time.** `ActionPlayback.sample` returns a snapshot without changing the selected clip. Completion maps to idle at the clip's end time; camera rendering and backward scrubbing cannot mutate selection. Hold-capable definitions now declare a loop range. Playback maps elapsed time into that range and schedules a return on request, completing the entrance first if necessary. The same phase identity persists across loop wraps; a return captures the current skeletal/facial pose for blending. Persistent wearables use a separate `WearablePlayback` scheduler, described below. General action queues remain unimplemented.
- **Routines describe intent.** A sampler takes elapsed time and returns hand targets, body/head orientation, facial channels, and prop cues. It performs no I/O and creates no GPU resources. Immutable `MotionTrack` values validate ordered keys once and sample bounded, eased scalar/vector values without rebuilding key arrays per frame. Randomized performances will need an explicit seed so repeated sampling remains deterministic.
- **The rig owns anatomy.** Routines address `HandSide` and `RigAttachment`, never source joint IDs. The shared hand intent includes an explicit grip channel. `FanRig.attachmentFrame` supports offsets in character axes or axes that rotate with the joint. Joint frames remove scale/shear so glasses or held books remain rigid when the character deforms.
- **Facial channels share interruption behavior.** Jaw, eyelid closure, gaze, and smile offset blend as one `FacialIntent`; manual expression controls apply afterward. Smile offsets preserve the user's chosen neutral smile on return. Additional imported facial morphs still have their existing manual controls; automatic tracks for those channels remain to be added.
- **Props have stable identity and typed state.** `PropCue` names an asset, semantic attachment, transform, visibility, and `PropDeformation`. Fruit trimming and independent peel ribbons do not expose Metal uniform lanes to choreography. A thrown object changes to a character-space trajectory; an attached object follows the solved rig. Anchors can include a local socket transform and blend between two rigid attachment frames, supporting hand-to-head transfers without per-routine renderer code.
- **Playback state is separate from rendering.** `PropScene.swift` owns cues, resolved draws, and `PropMotion`. Retiring snapshots live in character space, so changing camera angles rotates them correctly. The current interruption policy contracts outgoing props over 0.20 seconds; object-specific stow/catch behavior remains necessary for full fidelity.
- **The renderer owns representation.** `PropGeometry` and asset-specific geometry builders create reusable buffers. `PropRenderer` packs typed deformation parameters. Both Metal passes call `deformProp`, so an opening peel or shortened fruit casts the corresponding shadow. Adding a rigid asset must not accidentally activate a banana deformation; deformation mode is separate from material identity.

To add a routine, register its definition, author its pose/prop tracks, and supply any new asset geometry/material. Hand/head attachments, facial blending, camera changes, playback time, and generic interruption handling should require no routine-specific renderer or rig branches. New anatomical capabilities, such as a seated lower-body pose or a mouth contact marker, belong in the shared rig interface when a real routine needs them.

`--validate-routines` checks lifecycle bounds, channel values, unique prop identities, deformation/mesh compatibility, banana topology, attachment rigidity, camera invariance, and read-only playback seeking. Existing action-transition, prop-contact, neutral-image, and three-angle render checks remain separate: structural correctness does not prove visual fidelity.

`PropAssetData` reads a small, versioned indexed-mesh format, checking layout and indices before GPU upload. `Scripts/export-sunglasses.py` converts the fan model's existing glasses offline and fits them to the approved head shape. Generated props and imported prop assets use the same rendering path.

## Independent wearables

`Wearable` is the accessory catalog: each item supplies its transfer timing and persistent appearance. `WearablePlayback` stores the requested set separately from the physically worn set. One shared queue serializes hand transfers across accessories. An active transfer finishes before any reversal; pending transfers are rebuilt from the latest requested set in stable catalog order. The queue is bounded by the catalog size plus one active transfer. Repeated sets are idempotent and sampling is read-only, including repeated camera passes.

`CharacterPlayback` coordinates body playback and accessories; `Character` exposes its commands. A transfer temporarily reserves the body action slot, pausing its timeline and resuming it afterward. Routines declare an `handoffPolicy`: ordinary gestures pause and resume, while prop routines finish their authored stow before a transfer starts. A newly requested action during that wait or transfer starts when the transfers finish; the latest request wins. Once equipped, an accessory contributes a persistent head-attached prop cue and releases the action slot entirely. Return to rest affects the body, not the accessory boolean. Renderer consumes these cues through the same attachment, lighting, and shadow pipeline as routine props; it has no sunglasses-specific branch.

The app exposes Sunglasses and Headphones as independent checked toggles. Their complete reference performances remain available for offline validation. Persistent wear does not impose the reference performance's head turns, listening sway, or closed eyes on unrelated actions. The shared queue now arbitrates transfers between both accessories; general limb masks remain future work. The current scheduler protects prop routines by waiting for completion; it does not synthesize an early catch-and-stow motion.

`--validate-wearables` checks rapid reversals, repeated sets, action requests during transfers, resumed body time, deferred prop stow, cancelling a deferred removal, and head attachment across all other actions. It checks both accessories across all fourteen body actions, and renders seven combinations and removal from front, quarter, and profile views.

A hold-capable prop routine with `finishRoutine` transfer policy receives an explicit return request before a pending accessory transfer. Its return finishes before the hand slot changes owner. The legacy headphone reference performance exercises this case. Independently toggled headphones do not occupy that routine slot, so removing sunglasses leaves the headphones on. `--validate-headphones` covers this ordering as well as indexed mesh winding, finite normals, two-handed carry, and the rigid head attachment.

`MotionPath` supplies continuous-velocity spatial interpolation for flight, while `MotionTrack` retains eased stops for deliberate pose holds. Butterfly wings are separate rigid prop meshes sharing the body's anchor; their rotations do not require a special rig or shader deformation. `RigAttachment.indexTip` uses a terminal-joint marker calibrated to the fan mesh's distal finger samples. The rig computes pointing curls around the cross product of the authored finger and palm directions, so fingers curl toward the palm even with the hand raised vertically.

Props have their own `PropVarying` shader interpolants. Before shared lighting, the fragment shader explicitly clears anatomical eye/mouth channels. UV components used for wing patterns therefore cannot trigger eyelids, pupils, or lip shading. `--validate-butterfly-materials` compares a populated butterfly crop at the same pose with open versus closed eyes and changed gaze; shadows are disabled to isolate material behavior.


`StanceIntent` separates lower-body intent from imported joint indices. Routines supply a pelvis displacement, ankle targets, foot rotations, and knee bend directions; FanRig solves those targets and retains its local-joint transition blending. `changesStance` describes the resulting movement policy for validation. `PropDeformation.page` carries curl into the common color/shadow deformation path.

Interactive `request` differs from low-level `play`: menu requests respect `handoffPolicy`, whereas direct playback remains useful for deterministic previews and immediate speech synchronization. `RoutineDefinition.returnDelay` declares a safe delay before a held routine begins its return (reading finishes an active page turn). `ActionPlayback.completionTime` is the scheduling authority for the complete return, avoiding duplicated timing arithmetic in the coordinator and preview tools. Independent speech layered over reading remains future work.

## Continuing related routines

A `RoutineContinuation` declares a compatible family, an entry time inside the destination clip, the source interval that permits continuation, and a delay to its safe handoff pose. `CharacterPlayback.request` uses that contract before requesting a full stow. The queued playback begins at the declared elapsed time; the renderer remains unaware of routine families. Shared prop IDs prevent duplicate retirement draws. Requests during accessory transfers continue to use the existing hand-transfer queue.

Writing and Write Pause are the first family. Switching during retrieval waits for retrieval to finish; switching during a stroke waits for the pencil lift. Unrelated actions and accessory transfers still require the full stow. The existing skeletal/facial interruption blends handle changing gaze as the variants switch.

Continuations can also declare an outgoing clip phase. The paused writing variant uses it to raise the lowered pencil back to the shared grip before resuming. If reversal is requested while the hand is still lowering, the exit phase is selected at the same pose, avoiding a prop-position jump.
