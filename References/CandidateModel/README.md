# Conversion research history

These notes record successive experiments and include superseded results. The default app now uses the fan model. Canonical runtime assets moved to `Resources/FanModel/`; historical paths below retain their original spelling. See `Docs/assets.md` for current regeneration instructions. Raw downloads and generated variants stay local and are ignored by Git.

# Fan model conversion candidate

User approved pursuing this model on September 4, 2026, with no large application installs.

Creator: YinyangGio. Public model listing (credited uploader/Blender port: Landon & Emma, currently displayed as NitroShell): https://sketchfab.com/3d-models/bonzi-buddy-bonzibuddy-made-by-yinyanggio-f1595764955242b7ba38695d5732df37
The listing declares Creative Commons Attribution. Its creator-linked source download is https://www.mediafire.com/file/mqa9oc6hm2r2trk/The_good_the_bad_and_the_ugly.lib4d/file

The Workshop preview comes from sitkinator's later Source port: https://steamcommunity.com/sharedfiles/filedetails/?id=3492895008 . That port credits YinyangGio for the original model and Landon & Emma for the Blender port. The image is a reference, not bundled artwork.

`yinyanggio.lib4d` is the downloaded library. `blocks.json` records its SHA-256 and the extracted zlib block offsets. `block-5.c4d` contains the Bonzi Buddy scene. No embedded scene scripts were executed.

An isolated command-line reader was built against the official Cineware S22.008 SDK downloaded from https://developers.maxon.net/downloads/Cineware_22_008.zip . SDK files and the executable remain under `/tmp`; no Cinema 4D, Blender, or other large application was installed. The SDK is not linked into BonziBuddy.

Rebuild the reader with `bash Scripts/build-cineware-inspector.sh /tmp/bonzi-cineware-sdk`. Run `/tmp/bonzi-cineware-inspect References/CandidateModel/block-5.c4d References/CandidateModel/core-control-mesh.obj`.

Verified inventory:
- Four core polygon objects: head, mouth, body (`Sphere.1`), eyes.
- 4,269 control vertices and 4,236 control faces exported in world space to OBJ.
- Each core object has a weight tag referencing 44 joints.
- Head has base pose plus six eyebrow/expression morphs.
- Mouth has base pose plus nine named morphs, including smile, jaw, mouth, cheeks, nose and oh/kiss.
- Separate eyelid meshes and teeth exist under the head rig.

The OBJ is an initial geometry export, not a finished runtime asset: subdivision, material assignments, UVs, weights, morph data and eyelid controls still need conversion and verification. The existing procedural model remains the running app model.

## Structured interchange (September 5)

`scene.json` preserves all 64 scene objects and their hierarchy, local/world transforms, visibility modes, polygon control meshes, UV coordinates, material slots and polygon selections, four 44-joint weight maps and bind transforms, and 15 facial targets plus two base poses. Material colors are source metadata; the approved runtime palette and lighting are saved separately in `../ApprovedAppearance/`.

Reproduce with:

```sh
bash Scripts/build-cineware-inspector.sh
/tmp/bonzi-cineware-inspect References/CandidateModel/block-5.c4d References/CandidateModel/core-control-mesh.obj References/CandidateModel/scene.json > References/CandidateModel/scene-inventory.txt
python3 Scripts/check-fan-export.py > References/CandidateModel/export-check.json
```

Checks cover finite data, hierarchy and face indices, UV counts, material selection references, joint references, weight normalization tolerance, and morph size/nonzero changes. Body weights have source quantization error below 0.0001; normalize when converting for runtime use.

This is source data preservation, not evaluated Cinema 4D animation. Subdivision settings/creases, morph evaluation semantics, facial control mapping, accessory visibility and Metal integration still require visual validation. No fan geometry has replaced the running app yet.

## Native Metal preview

Run `python3 Scripts/convert-fan-preview.py`, `bash Scripts/build.sh`, then `Build/BonziBuddy.app/Contents/MacOS/BonziBuddy --preview-fan`. The separate preview uses two Catmull–Clark subdivision levels (135,168 triangles), approved palette mappings, and the existing lighting, four-sample AA and shadow pipeline. Output is in `Validation/FanPreview/`; the desktop app continues to load the procedural asset.

The pupil mask is evaluated in Metal from the source circular-gradient knots and each texture tag's following UVW map. Source scalar/vector/string material settings, shader hierarchy, gradient knots and texture projection transforms are now included in `scene.json`. This metadata does not reproduce every proprietary shader feature or channel link.

Visual review: the imported muzzle, cheeks and feet have more coherent profiles; both pupils appear after selecting the separate eye UV maps. The static T-pose, brow/crown proportions, torso seams, eye highlights and original-smile match still require work. This preview is not a completed likeness or animation validation, and no 120 Hz performance claim has been made for it.

## Imported rig preview

`--preview-fan` now loads `FanRigged.mesh` and `FanRig.json`, and writes to `Validation/FanRigged/`. `FanPreview.mesh` and `Validation/FanPreview/` retain the static source-pose reference. The app default remains the procedural model.

The native rig uses the exported joint hierarchy, transforms vertices in Metal with up to eight normalized influences, and shares deformation between color and shadow passes. Subdivision interpolates the source weight fields before packing. Eight-influence truncation discards at most 0.014581 weight per vertex (mean 0.00012465); the untruncated source remains in `scene.json`. This residual approximation needs checking during stronger finger/elbow poses.

The preview lowers arms about source shoulder pivots and adds small spine breathing. It does not yet reproduce the original hands-together idle, wrist wave or facial animations. The source geometry is normalized consistently with joint positions; current source-pose matrices are used as the rest frame, retaining the original C4D bind matrices separately in the interchange file.

Verification:
- `python3 Scripts/check-fan-mesh.py`: finite packed data, indices and joint references, unit normals, normalized weights.
- `--preview-fan`: neutral skinning matrix error below 0.000001; unchanged leg-joint transforms across eight seconds of idle samples; five angle renders and 300 warmed-up GPU frames.
- `xcrun swift -module-cache-path .build/clang-cache Scripts/compare-fan-bind.swift`: static versus neutral-skinned image MAE approximately 0.00000308 in premultiplied RGBA. This is an import consistency check, not original-likeness evidence.
- Apple M4 Pro, 800x640, 4x MSAA, soft shadows: offscreen GPU p95 1.886 ms, maximum 2.290 ms. Live display pacing is not yet measured for the fan asset.

Visual review: lowered shoulders and attached hands appear coherent in the front/quarter/left renders. The hands currently hang low, the torso has visible material/anatomy seams, and the model still needs original-pose and facial comparison work.

## Clasp pose and original comparison

The rest preview now aims the imported shoulder/elbow/wrist chains toward a hands-together pose, offsets the two forearms, and curls the finger joints. Five-angle renders show coherent elbow bends, but the clasp remains too bulky and the elbows too close to the torso compared with the original.

The existing comparison scripts now accept optional render-path and output-folder arguments, preserving their default procedural-model behavior and unchanged likeness thresholds:

```sh
xcrun swift -module-cache-path .build/clang-cache Scripts/compare.swift Validation/FanRigged/front.png Validation/FanRigged
xcrun swift -module-cache-path .build/clang-cache Scripts/smile-review.swift Validation/FanRigged/front.png Validation/FanRigged
```

Visual inspection of the original/current/diff panels identifies narrower head and body silhouette, taller pointed crown, longer straight legs, insufficient elbow spread, and a central muzzle crease absent from the original. The original likeness gate still fails. The fixed normalized face crop is useful diagnostically but is not landmark-aligned; proportion differences also affect its pixel error. These images do not establish an identical smile.

## Proportion and ground-contact pass

The posed rig lowers the hips by 0.09 units, solves two-segment bent legs to stationary ankles, spreads and turns the feet outward, extends the upper-arm rest offset by 35%, and broadens/shortens the head by factors 1.13/0.93. These are runtime pose adjustments; the source-pose geometry remains unchanged. A 0.02-unit placement offset aligns the posed soles with the renderer’s -0.92 ground plane.

Visual review of front and left renders: wider elbow placement and the squat stance move toward the original; the pointed crown, facial center crease and bulky clasp still need correction. The original comparison remains a failure: silhouette IoU 0.787414, foreground RGB MAE 0.229711 (previous clasp: 0.725232 / 0.258407). Palette and lighting are unchanged.

Validation checks 6,432 weighted foot-surface vertices at 60 times across eight seconds. Idle drift is zero; minimum foot Y is -0.920559, within the 0.002 contact tolerance. Final offscreen GPU p95 is 2.844 ms with 4x MSAA and soft shadows; this does not establish live 120 Hz pacing.

## Native facial morphs

`python3 Scripts/build-fan-morphs.py` converts the source `smile`, `jaw`, and `eyebrow up` targets with the same subdivision and normalization as the base mesh. It checks identical topology, materials, UVs and weights, then packs position and normal deltas into `FanMorphs.bin`; `FanMorphs.json` records names and changed-vertex counts. The full-strength meshes remain in `MorphVariants/` for independent endpoint rendering.

Metal blends up to two selected targets before eight-influence skinning. Both visible and shadow passes use the same morph calculation. `--preview-fan` renders each target at half/full strength from front, quarter and left, writes separately baked endpoint renders, and benchmarks two continuously changing morph weights. The desktop app still uses the procedural model; these controls are currently in the fan preview pipeline.

Endpoint image checks use `Scripts/compare-fan-bind.swift` with baked image, GPU image and output JSON arguments. Smile, jaw and eyebrow checks each have premultiplied RGBA mean error below 0.0000034. This establishes conversion consistency, not the original expression match. Intermediate normals use normalized linear interpolation; stronger combined expressions still need visual checks.

Visual inspection: smile and jaw open the integrated mouth without detaching the muzzle in the quarter view. The raised brow opens more space above the eyes. Teeth, eyelids, additional targets and expression timing remain unfinished. Source smile at full strength is an open-mouth grin, not the original closed resting smile.

With two animated morphs, the latest offscreen timing is p95 3.565 ms but maximum 27.079 ms. The outlier exceeds the 120 Hz frame budget and remains unresolved; do not claim smooth 120 fps from the percentile. See `Validation/FanRigged/checks.json` and `Validation/FanRigged/Morphs/*-check.json`.

## Live 120 Hz investigation

`Build/BonziBuddy.app/Contents/MacOS/BonziBuddy --onscreen-fan-validation` runs the fan renderer in the normal native transparent window, continuously blends smile/jaw, breathes through the spine and sweeps the view angle. It records drawable presentation timestamps after 120 warmup frames and stage timings for 1,200 measured frames. The report includes actual drawable size and device. It does not exercise the original action set, which is not yet retargeted to this model.

A still-running procedural Bonzi process was found during the previous offscreen tests. It was stopped for two isolated live runs, and the normal desktop app was restored afterward. This is evidence of a possible competing workload, not proof of the cause of the earlier 27 ms outlier.

Live results on Apple M4 Pro, 800x640, 4x MSAA and soft shadows:
- First run: 119.700 presented fps, three intervals above 12.5 ms; GPU maximum 3.852 ms.
- Second run: 119.800 presented fps, two intervals above 12.5 ms; GPU p95 3.171 ms, maximum 3.716 ms.
- Both: presentation p95 8.3334 ms; maximum presentation interval 16.6667 ms; no in-flight or missing-drawable skips.

`onscreen-performance-first-run.json` and `onscreen-performance.json` preserve both runs under `Validation/FanRigged/`. Draw callback submission time is dominated by drawable acquisition, not command encoding. The native fan workload runs close to 120 Hz with occasional doubled presentation intervals; perfectly steady pacing and full-action performance remain unproven. Removed an unnecessary procedural-character pose evaluation from the fan render path.

## Wrist wave and interactive preview

`--validate-fan-wave` renders a 3.2-second sequence from front and quarter at 30 fps into `Validation/FanWave/wave.gif`. It raises the arm, opens/turns the palm, waves at the source wrist joint (42), and returns to the clasp. The wrist swing is blended as a rotation about that joint, not about the palm center.

Validation across 96 frames reports wrist pivot error 0.0000002403, zero change to shoulder/elbow/preceding hand-joint transforms from wrist swing, visible finger travel 0.08694 units, and no viewport clipping. Visual inspection of frames 8, 25, 50 and 82 shows coherent raised arm and open palm from both cameras. The transition passes close to the cheek; intersection-free motion and original choreography are not yet established.

The same validation now exercises live action routing: wave, local-speech morph movement, then idle reset. `open -n Build/BonziBuddy.app --args --fan-model` starts an interactive preview with Wave, local speech, jokes/time and camera views. Unsupported fan action menu entries are omitted while they are retargeted. The fan assets and attribution are bundled under app Resources/CandidateModel; no SDK is bundled. Normal launch still selects the procedural model. The interactive fan preview was launched after validation for review.

## Expressive controls, blink and restored action menu

All 15 source facial targets now export to `FanMorphs.bin` and are available simultaneously through a named expression panel. The neutral live expression uses 20% `smile` and full `eyebrow up` to remove the low, stern brow; speech preserves that brow while driving the jaw. Right-click **Facial expressions…** for additive morph controls, manual eye closure, horizontal/vertical gaze, automatic-blink toggle and reset. Slider overrides take precedence over automatic expression weights until reset. Source controls named `?` and `¿` are conservatively labeled Brow variant 1/2.

The Metal morph pass now supports the full 15-target set. `build-fan-morphs.py` checks topology, materials, UVs and weights for every target before packing. Blink closes quickly, holds, then reopens using the existing 4.6-second cycle; clap and shrug also retain their blink curves. Current lids are a skin-colored animated cover/crease on the eye mesh, not separately rigged eyelid geometry. Gaze compensates for the two eyes’ mirrored UV maps.

The fan action menu restores Look Left/Right, Clap, Shrug, Dance, Think and Surprised alongside Wave. Clap and shrug reuse their existing reference-keyed curves; other actions use the existing local pose targets retargeted to the fan joints. Palm frames were corrected after visual inspection so shrug faces upward and clap has opposing palms. These are functional ports, not yet exact original choreography.

`--validate-fan-actions` captures all ten action durations in front/quarter views to `Validation/FanActions/`, totaling 505 frames and 1,010 rendered views, with no viewport clipping. It also renders blink phases, gaze directions and a four-target expression combination. `--face-only` limits this command to facial checks under `Validation/FanFace/`. Visual review covered clap/shrug/dance/think/surprised poses and open/closed blink. Think still brings the hand very close to the cheek and needs collision/choreography refinement.

The panel was visually captured using `--fan-model --validate-expression-ui`. It includes all named sliders and reset; initial scroll position was corrected to start at the top. The following section records the subsequent teeth integration and updated workload measurement.


## Teeth and neutral smile

The interactive fan preview now includes the source upper/lower polygon teeth (29,696 triangles), attached to the head rig and rendered through the same Metal lighting and soft-shadow passes. Lower teeth are fitted inside the jaw and move with smile/jaw opening; narrow-mouth controls also narrow the dental geometry. This is a procedural retarget of the source dental meshes, not a separate authored dental animation rig.

`--validate-fan-teeth` renders seven smile/jaw states at front, quarter and left plus five other expressions at front and left. Visual inspection includes the 20% neutral smile, speech, sad, little-mouth and oh/kiss profiles. The closed-mouth comparison against teeth disabled has mean pixel error 0.00000333; teeth do not materially alter the closed face. Arbitrary combinations of every facial target are not exhaustively proven intersection-free.

The live neutral smile and expression-panel reset both use 0.2, with the relaxed raised brow. Existing skin colors, lighting, 4x MSAA and soft-shadow settings are preserved.

The updated `--onscreen-fan-validation` switches through all ten local actions at one-second intervals using the live action path, including automatic blink, neutral smile, speech jaw and teeth. This tests interrupted action transitions; full-duration animation fidelity is a separate check. The earlier continuous two-morph/yaw benchmark is retained as `onscreen-performance-two-morphs.json`.

Updated action workload on Apple M4 Pro at 800x640: 119.900 presented fps across 1,200 samples, presentation p95 8.3334 ms, one interval above 12.5 ms (maximum 16.6667 ms). GPU p95 3.469 ms, maximum 3.775 ms; no in-flight or drawable-unavailable skips. This supports near-120 Hz operation for the measured workload, not perfectly steady pacing or exhaustive simultaneous facial-target coverage.

The 20% neutral face with teeth was compared against the original idle reference in `Validation/FanNeutralComparison/`: silhouette IoU 0.787414 and foreground RGB MAE 0.229233, failing the unchanged 0.95 / 0.05 near-identity thresholds. This remains an intermediate fan-model port; the current crown, body proportions, resting arms and muzzle differ from the original.


## Original resting-arm comparison

Adjusted the fan upper-arm reach and elbow directions to lower and widen the original-like triangular clasp. Forearm reach and direction keep the hands in front of the upper torso. Resting wrists now use an explicit palm frame, so changing elbow angles no longer inadvertently rolls the palms upward. Action offsets share the same resting directions.

Front, quarter and left renders were visually reviewed under `Validation/FanTeeth/neutral-*.png`. `Validation/FanRestComparison/comparison.png` compares the revised idle against the original: silhouette IoU increases from 0.787414 to 0.817269 and foreground RGB MAE falls from 0.229233 to 0.210719. The unchanged near-identity gate still fails. Crown/muzzle/body proportions and the fine finger clasp still differ from the reference.

Rebuilt and rerendered all ten actions with teeth enabled: 505 frames, 1,010 camera views, no viewport clipping. The 96-frame wrist-wave check reports pivot error 0.0000001885 and no preceding-arm change from wrist swing. Visual checks covered wave, clap, shrug, think and surprise. Think remains a raised open hand near the cheek rather than a convincing thinking contact pose; choreography and mesh-intersection fidelity are not established. These pose-only changes do not constitute a new performance measurement.


## Pupil catchlights

Added a small antialiased white catchlight to each fan-model pupil. The pupil UV frame compensates for the mirrored eyes, so gaze moves the pupil and its highlight consistently; the blink mask hides the highlight as the lid closes. This is a stylized surface highlight, not physical corneal reflection geometry. The additional effect is enabled only on the imported fan path; skin lighting and shadow parameters are unchanged.

`--validate-fan-actions --face-only` now emits on/off eye renders at front, quarter and left under `Validation/FanFace/`, alongside blink/gaze checks. Visual review confirmed highlights on both visible pupils, consistent upward gaze and no visible catchlight at full closure. `Scripts/smile-review.swift ... --eyes` adds an eye-region crop without synthesizing reference detail. `Validation/FanEyeComparison/eyes-review.png` compares the original, current render and absolute difference. Global silhouette IoU remains 0.817269; RGB MAE is 0.210615 and still fails the original-likeness gate. Eye placement/proportions relative to the muzzle remain visibly different.

The fan pupils were subsequently reshaped to taller ovals (UV radius multipliers 1.15 horizontal / 1.6 vertical, center raised by 0.035 UV). The procedural model keeps its prior pupil shape. The face-only renders now cover all four cardinal gaze limits and two diagonal limits at full slider strength, along with neutral three-angle and blink views. Visual inspection confirmed oval silhouettes, coherent mirrored gaze, and lid occlusion. The global comparison after this change is IoU 0.817269 and RGB MAE 0.211698; it still fails the unchanged likeness gate. Eye placement and the surrounding head geometry remain unresolved.


## Upper-face placement

Added a smooth vertical shape correction after facial morphing and before skinning, shared by color and shadow passes. The eye/brow region rises by up to 0.10 mesh units; the displacement transitions into the upper muzzle and forehead, with a flat central region to avoid stretching the eyeballs. Normals use the inverse deformation Jacobian. Source-pose mode bypasses this correction so imported bind geometry remains inspectable.

`Validation/FanUpperFaceComparison/` retains the previous front/quarter/left and the updated original comparison. Visual inspection covered the three neutral angles, combined facial targets, closed/partial blinks, gaze extremes, open jaw and full-smile profile. The silhouette IoU is now 0.821013 (previous 0.817269), and foreground RGB MAE is 0.204581 (previous 0.211698). The unchanged near-identity gate still fails; muzzle shape and overall proportions remain visibly different.

The native preview checks pass: source-pose matrix error 0.000000775, zero idle foot drift across 6,432 weighted foot samples and contact at -0.920559. The preview's offscreen timing is not a new onscreen performance claim. No skin color, light or shadow parameter was changed.


## Interrupted action blending

The live fan path now retains the last displayed skeleton and blends into a newly selected action over 0.20 seconds. A second interruption captures the already blended pose. Local translations, quaternion rotations and stretch/shear are blended within the hierarchy; polar decomposition preserves imported joint shear that a rotation-plus-scale decomposition lost. Offline direct-pose inspection remains available, and ordinary action curves are unchanged after the blend completes.

`--validate-fan-transitions` covers all 100 ordered action pairs, sampling 30 transition frames each and interrupting each pair again during an active blend. Maximum matrix jump at the interruption is 0.000001073, settled error is zero, and maximum leg-matrix drift is 0.000000417. Front and quarter snapshots of rapid wave → dance → shrug are stored in `Validation/FanTransitions/` and were visually reviewed. This verifies skeletal continuity and convergence; facial-expression switching, collisions and exact original choreography remain separate work.

Updated live measurement with face geometry and skeletal blending: 119.601 presented fps across 1,200 samples at 800x640, 4x MSAA and soft shadows on Apple M4 Pro. Four presentation intervals doubled to 16.6667 ms; p95 stayed 8.3334 ms. GPU p95 3.211 ms and maximum 3.705 ms, with no skipped submissions. This remains near-120 Hz with occasional pacing misses, not a perfectly steady 120 fps result.


## Default bundled app launch

Normal launch now selects the imported fan model. `--fan-model` remains compatible; `--procedural-model` explicitly selects the historical procedural renderer. `--onscreen-validation` measures the selected model, so the old procedural benchmark requires `--procedural-model --onscreen-validation`.

The build requires all six fan asset/attribution files before compiling and always copies them into the app. Strict code-signature verification and SHA-256 equality for each bundled file pass (`Validation/BundledLaunch/asset-checks.json`). The executable was launched from `/tmp` without a model-selection flag; its native 15-morph expression panel was captured to `Validation/BundledLaunch/controls.png`. This verifies the default fan selection and resource loading outside the source working directory. No SDK or source scene is required at runtime.


## Automatic facial transitions and appearance checkpoint

Automatic jaw and action-specific eyelid weights now blend from their last displayed values over 0.15 seconds when an action changes, including a second interruption during the blend. Global periodic blinking continues independently. Manual morph overrides are applied after the automatic jaw weight, and manual eye closure still composes with automatic blinking. The 20% neutral smile, materials and geometry are unchanged.

The transition validator adds 300 facial cases across all action pairs and three interruption times. Maximum initial facial jump and settled target error are both zero. Speech-stop snapshots were reviewed and wave/speech/idle routing passes after allowing the jaw blend to settle. This remains procedural speech timing, not phoneme-accurate lip sync.

The user reports being about 90% satisfied with the overall appearance. `References/ApprovedFanAppearance/` saves the current front/quarter/left renders, geometry/shader hashes and source snapshots. Preserve that overall appearance and prioritize motion, expression control and behavior; this feedback does not establish exact original identity or complete feature coverage.


## Independent eye closure

The facial panel now has Both eyes closed, Left eye closed and Right eye closed controls. Left/right are anatomical: Bonzi's left eye appears on the viewer's right in a front view. Each eye combines its own manual closure with the shared blink/closure amount. Reset clears both individual values. The existing eye-surface lid mask and catchlight occlusion are reused; this does not introduce separate anatomical lid meshes.

The face-only validator renders left and right winks and asymmetric partial closure from front, quarter and left. Visual checks confirmed the intended eye closes, the other stays open, and catchlights disappear behind the closed lid. `Validation/FanFace/neutral-preservation.json` compares the unchanged neutral face against the user's appearance checkpoint.


## Choreography and pose refinement

At the user's request, work returned to animations while preserving the appearance checkpoint. Clap and shrug were reviewed against their local classic sprite sequences. The arm retarget now solves shoulder/elbow positions from wrist goals for clap, shrug, think and dance, preserving the rig's limb reach instead of approximating wrist positions with angle offsets.

Clap aligns the two palm surfaces in depth and across the body, with an upper-palm strike on the lower upturned palm. A weighted-surface check samples 81/74 palm vertices: nearest distance is 0.063564 on the open beat and 0.000775/0.000784 on the two contact frames. The check requires separation above 0.04 and contact below 0.01. This verifies contact proximity, not a complete penetration analysis.

Shrug uses lower, wider palms-up goals and a corrected preparation/return that brings the hands back across the chest. Thinking uses a directed hand placement near the chin, dedicated finger/thumb curls and a slight head lean toward that hand. Dance uses a slower alternating arm rhythm, bent elbows, open palms and restrained torso sway; feet stay planted. Wave and glances retain their existing curves.

`Validation/FanActions/review.html` collects looping previews with original reference strips where available. Full-duration captures now include front, quarter and left profile: 505 frames / 1,515 views, no clipping. Visual inspection covered clap separation/contact, shrug opening/return, thinking hand shape, alternating dance phases, wave, glances and surprise. All 100 skeletal transition pairs and 300 facial transition cases pass after these changes. Neutral appearance comparison MAE is 0.0000000895 against the saved user checkpoint. Exact Windows choreography and exhaustive collision freedom are not established by these checks.


The post-choreography live performance run unexpectedly presented at about 60 Hz despite a reported 120 Hz screen maximum and GPU p95 around 3.1 ms. A second isolated run repeated it; no other Bonzi process was running and `pmset` reported low-power mode disabled. Most submission time was drawable acquisition (~16 ms), while command encoding p95 remained below 0.4 ms. An `afterMinimumDuration(1/120)` presentation experiment did not resolve it and was reverted. Reports retain both baseline runs and the experiment. This is an unresolved pacing regression/state change, not evidence that the updated app currently achieves smooth 120 fps. The earlier near-120 Hz reports remain historical evidence only.
