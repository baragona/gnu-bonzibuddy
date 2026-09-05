# Development log (archived September 5, 2026)

Historical notes captured before repository organization. Paths in this document are relative to the repository root; results describe individual iterations, not current guarantees. See the current README and status document first.

# BonziBuddy for macOS

A native AppKit desktop companion rendered in real time with Metal. No external dependencies, third-party APIs, analytics, accounts, network requests, or background services. Speech uses macOS AVSpeechSynthesizer and available system voices.

## Run

Requires macOS 14+, a Metal-capable Mac, and Apple Command Line Tools.

```sh
./Scripts/build.sh
open Build/BonziBuddy.app
```

The build creates an ad-hoc signed local app. It compiles Metal source once at launch, so the full Xcode Metal compiler installation is unnecessary. Drag Bonzi to reposition him. Double-click to open the chat controls. Right-click or use the Bonzi menu-bar item for animations, jokes, time, voice mute, hide, and quit. Hiding pauses rendering. Voice mute and reminders you create are saved locally; typed speech is not stored. Standard macOS speech is not a recreation of the original Sydney voice.

The [animation review](Validation/FanActions/review.html) contains full-duration front, quarter and profile previews, with original reference strips for clap, shrug and glances.

## Reminders

Choose **Reminders…** from Bonzi’s menu, enter the text and date/time, then click **Add reminder**. Cancel pending reminders or mark delivered ones **Done**. Reminders stay on this Mac. Bonzi must be running to deliver them; overdue items appear when you next open the app. A due reminder opens the list and uses the existing speech bubble and optional local voice. No notification service or account is used.

## Current implementation

- Transparent floating desktop panel, supporting Spaces and fullscreen auxiliary windows.
- 4× MSAA (2×/1× fallback if unsupported), depth-tested, lit, skinned polygon geometry; genuine geometry with a rotatable model transform, not sprites or video.
- Idle breathing and blinking, reference-based shrug, clap, and left/right glances, wave, dance, thinking tilt, surprise, and speech mouth movement.
- Local speech, a small built-in joke collection, time announcement, and native reminders.
- Real-time self-shadowing and a transparent desktop shadow, using a 2048² depth map and blocker-dependent soft filtering.
- 120 fps requested from MTKView, triple-buffered bone transforms, bounded in-flight rendering, and live callback FPS/p95 statistics in the controls.

The normal app launch now uses YinyangGio’s imported fan model, with the source attribution bundled in the app. It includes all 15 facial morph controls, gaze, blinking, teeth, the 20% neutral smile, and 0.20-second skeletal blends when actions are interrupted. Right-click **Facial expressions…** to control the face. The app loads its model and shaders from its own Resources directory, so it can run outside this source folder.

This is **not a completed visually identical recreation**. The current original-image comparison has silhouette IoU 0.821 and RGB mean absolute error 0.205, below the required likeness gate. Animation choreography remains approximate. Earlier runs reached 119.60 fps on an Apple M4 Pro; the latest post-choreography runs are presenting near 60 fps despite GPU time below the 120 Hz budget. That drawable/presentation pacing issue remains unresolved. Games, singing, browsing/download helpers, and complete animation coverage are future work.

The earlier procedural renderer is retained for comparison with `--procedural-model`; `--fan-model` remains a compatible explicit selector. Detailed model provenance, visual comparisons and validation history are in [References/CandidateModel/README.md](References/CandidateModel/README.md).

## Validation

For the default fan model:

```sh
Build/BonziBuddy.app/Contents/MacOS/BonziBuddy --preview-fan
Build/BonziBuddy.app/Contents/MacOS/BonziBuddy --validate-fan-actions
Build/BonziBuddy.app/Contents/MacOS/BonziBuddy --validate-fan-transitions
Build/BonziBuddy.app/Contents/MacOS/BonziBuddy --onscreen-validation
```

The following commands and historical results concern the earlier procedural renderer:

```sh
Build/BonziBuddy.app/Contents/MacOS/BonziBuddy --validate
swift -module-cache-path .build/clang-cache Scripts/compare.swift
Build/BonziBuddy.app/Contents/MacOS/BonziBuddy --check-mesh
Build/BonziBuddy.app/Contents/MacOS/BonziBuddy --procedural-model --onscreen-validation
```

Run from this repository. GPU validation may require running outside a restricted terminal sandbox. The last command launches a separate 12-second test instance and exits automatically. After a one-second warmup it switches through all ten actions at one-second intervals, including interrupted transitions; it does not measure every full animation duration.

- `Validation/idle.png` and other action PNGs: actual Metal framebuffer readbacks.
- `Validation/comparison.png`: original reference / rendered idle / absolute pixel difference, with foreground bounding-box alignment preserving aspect ratio.
- `Validation/visual-metrics.json`: foreground silhouette IoU and normalized RGB mean absolute error. The explicit near-identical gate (IoU ≥ 0.95 and error ≤ 0.05) is **not met**. Nearest-neighbor reference enlargement exposes original pixels; this metric is diagnostic and not perceptual proof.
- `Validation/performance.json`: GPU execution times over 300 frames after 60 warmup frames at 800 × 640. Excludes CPU work, presentation, and compositor overhead; it does not establish onscreen 120 fps.
- `Validation/onscreen-performance.json`: draw-callback pacing, drawable presentation timestamps after warmup, and the reported screen refresh ceiling. The nested `presentation` object uses `MTLDrawable.presentedTime`. The `stages` object separates drawable acquisition, CPU command encoding/commit, and live GPU execution, and records skipped-submission counts.

Actual smooth 120 fps requires a 120 Hz screen and end-to-end profiling there. MTKView's requested frame rate is constrained by the current screen: https://developer.apple.com/documentation/metalkit/mtkview/preferredframespersecond

## Layout

`Character.swift` owns the modeling controls and rig poses; `Mesh.swift` bakes and loads the indexed polygon asset; `Renderer.swift` owns Metal resources and render submission; `Shaders.metal` owns transforms and lighting; `App.swift` owns desktop UI and local behaviors. Reference artwork is kept outside app resources. `Resources/Bonzi.mesh` is the bundled skinned mesh; `Resources/Bonzi.obj` is an editable neutral-pose geometry export. The runtime draws indexed triangles, not primitive instances. The build automatically rebakes the mesh when modeling sources change. Use the direct compiler build script. This machine’s SwiftPM manifest library is incompatible with its Swift compiler, so the project does not depend on SwiftPM.

## Recorded polygon-renderer result

On the Apple M4 Pro with 4× MSAA and soft shadows, the latest action sweep recorded 119.90 presented frames/sec over 1,200 drawable presentation timestamps. The p95 presentation interval was 8.33 ms, with one 16.67 ms interval. CPU command encoding/commit p95 was 0.29 ms; live GPU execution p95 was 6.27 ms (maximum 7.34 ms). There were no skips from the in-flight limit or unavailable drawables. Drawable acquisition accounted for most submission waiting. These measurements cover this machine and run, not a guarantee on every Mac. The near-identical visual gate remains unmet.

## Polygon mesh validation

`Validation/mesh.json` records asset size and topology. `Validation/mesh-checks.json` records binary/index/weight validation and 1,200 sampled animation frames, including interruption continuity. `Validation/three-quarter.png` and `Validation/wireframe.png` expose actual 3D geometry. `Validation/performance.json` is regenerated with the mesh renderer and 4× MSAA. The likeness comparison remains below the required threshold; this is an intermediate mesh, not a finished likeness.

## Visual review

`Validation/angles.png` contains eight front, quarter, side, rear, and elevated captures of the same animated mesh. `Validation/shadows-on.png` and `Validation/shadows-off.png` compare the real-time shadow pass at an identical pose. The multi-angle review exposed and led to corrections for the floating mouth and hanging feet; the mouth now has a carved recess and the feet sit on a ground plane. Head, ear, shoulder, hip, and foot proportions have been refined against the reference. The current silhouette overlap is about 91.6%, up from 79.6%; the requested near-identical likeness is still not achieved.

The latest facial pass adds a curved smile recess, a separate tapered purple nose, rounder pupils, overlapping resting hands, and reference-sampled lavender colors. Facial topology uses finer sampling than the body. Speech deforms the lower face and uses matching geometry in the shadow pass; jaw interruption continuity is covered by the mesh checks. The head and body are separate closed anatomical surfaces.

## Reference animation comparison

```sh
Build/BonziBuddy.app/Contents/MacOS/BonziBuddy --validate-animations
swift -module-cache-path .build/clang-cache Scripts/compare-animation.swift
```

`Validation/shrug-animation.gif` previews the continuously interpolated 3D shrug. `Validation/shrug-comparison.png` compares original frames, native renders, and differences using a fixed 5:4 canvas, without per-frame alignment. The animation likeness gate is not met. The sequence uses community-hosted original sprites and the community client's 15 Hz tick; exact original Windows timing has not been authenticated. See `References/animation-source-notes.md`. Reference assets are not bundled with the app.

## Arm deformation and wave review

The arms now use indexed polygon rings along a continuous shoulder–elbow–wrist spline. Metal evaluates the same surface for color and soft shadows. This replaces the collapsing blend between the old arm segments; closed end caps sit inside the shoulder and palm. The wave uses a shorter hand rotation, a lower elbow, an open palm, and hand rotation at a fixed wrist. Its choreography is still an approximation of the original.

`--validate-animations` also writes `Validation/wave-animation.gif`: the complete four-second wave viewed from the front and left side. `Validation/Wave/` contains selected review frames, and `Validation/wave-animation.json` records clipping checks across 120 frames and both cameras. Preview playback is 30 fps; the app evaluates the motion continuously at its display rate. Mesh format version 3 adds articulated arm and eyelid parameters.

The latest proportion pass corrects inward-facing feet to an outward toe splay, enlarges the eyes, reduces the nose, fills out the legs, and refines the belly and lower face. Idle silhouette IoU is 0.9158 and foreground RGB MAE is 0.1438; both remain short of the near-identical gate. Eight-angle captures and the wave/shrug previews are regenerated for this mesh.

The wave keeps the forearm and wrist fixed during its repeating hand motion. A 360-sample regression check verifies this independently of body breathing, while confirming that the hand actually rotates. This removes the sideways wrist translation that made the palm appear to be the pivot.

Clap is available in the animation menu. It retargets reference frames 10–15, repeats the upper-palm/lower-palm gesture six times, and returns to rest. `Validation/clap-animation.gif` and `Validation/clap-comparison.png` expose the current motion and remaining likeness differences. Reproduce the fixed-canvas comparison with `swift -module-cache-path .build/clang-cache Scripts/compare-animation.swift --clap` after `--validate-animations`. The clap likeness gate remains unmet, and hand shaping/contact still needs refinement.

The palm geometry now starts at the wrist base instead of extending behind the pivot. The distal arm surface extends into the palm to close the wrist seam. Clap palm orientations and contact offsets have been corrected; selected open/contact side views are in `Validation/Clap/6-side.png` and `Validation/Clap/8-side.png`. These improve contact but do not establish original animation identity.

The current material pass broadens the highlights and separately calibrates fur, belly, and muzzle colors against fixed reference patches. `Validation/visual-metrics.json` includes those patch means for diagnosis; the original full-image likeness gate is unchanged and still fails.

The inner-mouth backing now sits behind the carved smile instead of intersecting the lips. Upper teeth are placed behind the upper lip, and dark oral surfaces use reduced highlights. `Validation/speech-review.png` shows six mouth openings from the front and three-quarter view. Speech remains an approximate jaw cycle, not original phoneme animation.

Idle breathing now moves the body by 0.004 model units while the feet stay fixed. A 600-sample check records zero foot-transform drift. `Validation/idle-animation.gif` shows the full five-second cycle from front and side. Blinking uses closed polygon eyelid patches that travel over stationary eyes; it no longer squashes the eyeballs. The blink closes in 80 ms, pauses for 40 ms, and reopens over 160 ms. Reference-driven clap/shrug lid timing remains separate.

Left/right glances are available in the animation menu. They retarget classic frames 143–146 and 149–152, turning the head independently of the torso. The hold duration is chosen locally. `Validation/lookleft-animation.gif` and `Validation/lookright-animation.gif` show the complete gestures. Reproduce the frame comparisons with `Scripts/compare-animation.swift --look-left` or `--look-right`; both likeness gates remain unmet.

Idle breathing also expands the torso by ±0.6% in width and ±0.8% in depth. Validation measures torso expansion as well as translation and checks that all foot transforms remain fixed. The wave test removes torso scale before comparing forearm motion, so breathing does not hide an unintended wrist translation.

Right-click Bonzi or use the menu-bar item, then choose **View from** to inspect the live mesh from the front, three-quarter, left, right, back, or above. Choose Front to restore the normal view. Animation poses now blend in character space before camera rotation is applied. A regression check changes the view during a wave-to-dance interruption and verifies that the underlying pose remains identical across cameras.

The latest leg correction turns the ankles inward rather than flaring them outward. Fixed-row silhouette measurements identified the mismatch; these are now recorded in `Validation/visual-metrics.json` alongside the unchanged full-image gate. Foot positions remain grounded and the eight-angle and animation captures are refreshed for this mesh.

The skull and lower torso now use locally shaped volume profiles in the offline mesh bake: a narrower crown tip, fuller crown shoulders, and fuller lower torso. Ear spacing is slightly wider. These are genuine three-dimensional mesh changes; the runtime still renders the same indexed asset from every angle. Fixed-row silhouette diagnostics now cover the head through the feet.

Idle leg motion tapers toward the planted feet: thighs receive 35% of the torso breathing displacement and shins 8%, while heels and toes remain fixed. This keeps breathing concentrated in the upper body instead of lifting the legs as a rigid unit.

The resting hands now overlap with the left hand in front, sit slightly lower, and use narrower closed palms. A fixed hand-region RGB difference fell from 0.1610 to 0.1394; full-image RGB MAE fell from 0.1430 to 0.1403. These diagnostics show improvement, but do not meet the original likeness gate. All ten actions pass transition checks, and wave/clap/shrug/idle/glance captures are refreshed for the revised hand mesh.

Left and three-quarter review drove a depth pass: the belly is inset into the torso with a deeper blend, eye sockets support the sclera, and brows sit closer to the forehead. Baked colors now blend across all contributing modeling volumes, avoiding discontinuities where the nearest pair changes. Feet have a fuller inward arch and a tapered upper surface leading to narrower toes. The front diagnostic improved to 0.9252 silhouette IoU and 0.1375 RGB MAE. Side views are design reviews, not verified matches to an authenticated original side model. Topology, animation transitions, wrist pivot, and grounded idle checks pass.

The subsequent profile pass replaces the broad foot oval with a narrower heel widening toward the forefoot, reduces lower-muzzle width, extends the nose with an attached base, and retracts fully open lids into the forehead. Brow ends are thinner. Arm rings now use the bend-plane normal rather than a fixed axis that could twist near the elbow; shading normals follow both curvature and taper. Current front IoU is 0.9172 and RGB MAE 0.1397, a regression from the previous front-only fit; the changes address the visibly implausible side geometry and do not establish finished likeness.

`Scripts/smile-review.swift` writes `Validation/smile-review.png`: a fixed normalized face crop enlarged 4× with nearest-neighbor sampling, showing original / Metal / absolute difference. Visual inspection drove a lower smile center, moderately stronger curvature, softer purple lip/recess colors and a darker lower muzzle. Head surface sampling is finer to resolve the narrow crease. The central muzzle still differs from the original; neither this crop nor the full-image comparison passes as identical. Brows are curved backward toward the temples in the baked mesh to reduce exposed tips.

The next depth pass makes the cheeks deeper inside the head, draws the lower chin back, seats the eyes slightly deeper, and reduces rear skull depth while preserving its front extent. Brows are wider in cross-section with shorter curved tips. `Scripts/face-depth-review.swift` produces `Validation/face-depth-review.png`: before/after columns, left/three-quarter rows, using saved baseline renders in `Validation/FaceDepth/`. These close-ups show structural changes rather than claiming original side-view identity. The current front comparison is 0.9158 IoU / 0.1466 RGB MAE and still fails the likeness gate. Blink, speech, topology, pose interruption, grounded feet, and wrist checks were reviewed for this mesh.

The upper muzzle now includes a central volume welded into the cheek surface, filling the recessed area between the cheeks and tapering down toward the smile. Its forward projection was reduced after side-view review exposed a protruding lip. The rig now has 61 transforms. The current full-image RGB MAE is 0.1438; the original likeness gate remains unmet.
