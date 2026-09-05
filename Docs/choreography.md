# Choreography and props

Implementation in progress; the complete visual-repertoire goal remains open.

`Routines.swift` samples continuous hand intentions, body facing, head motion, gaze, and prop cues from an action's elapsed time. A routine owns its reveal/hold/stow beats. `FanRig` turns wrist targets into two-bone IK and blends palm/finger intentions with the approved rest pose. Existing actions retain their current reference curves.

`PropMotion` resolves prop anchors after the rig has evaluated and blended its pose. A joint anchor currently tracks joint position, with offsets expressed in the blended character axes; prop rotation is explicit. It preserves outgoing props during interruption and contracts them over 0.20 seconds. This is a first interruption policy; held books, headphones, and thrown objects will need dedicated return/release behavior rather than assuming every prop should contract.

`PropRenderer` owns reusable polygon buffers and the separate rigid-prop vertex pipeline. The prop and character color passes use the same lighting helper; both write the same soft-shadow depth pass. The globe uses a 1024×512 mipmapped land mask baked from public-domain Natural Earth polygons. No runtime network access is involved.

Implemented first: globe reveal, fingertip support, whole-body facing, spinning, gaze toward it, and stow. Its sampled wrist attachment and interruption lifecycle have numerical checks. It is an authored 3D approximation, not yet an original-animation fidelity pass.

## Checks

```sh
./Scripts/build.sh
Build/BonziBuddy.app/Contents/MacOS/BonziBuddy --validate-props
Build/BonziBuddy.app/Contents/MacOS/BonziBuddy --validate-juggle
Build/BonziBuddy.app/Contents/MacOS/BonziBuddy --validate-fan-actions --action juggle
Build/BonziBuddy.app/Contents/MacOS/BonziBuddy --validate-fan-actions --action globe
Build/BonziBuddy.app/Contents/MacOS/BonziBuddy --validate-fan-transitions
```

The action filter enables focused three-angle reviews while keeping the full suite available. Original frame strips live under `Validation/Original/`; see the reference extraction instructions in `References/AnimationInventory/README.md`.

## Outstanding scope

Banana and miss variation; sunglasses; coconut headphones; butterfly interaction; seated book reading; writing pad/pencil; bamboo mailbox/letter variants; vine and surfboard movement/entrance/exit; chest beating/backflip; hugs/kisses/giggles/shushing; directional presentations and explanations; richer facial/gaze/idle sequences. Each needs actual geometry where applicable, reference-based choreography, clean entry/return/interruption behavior, multiple-angle review, and runtime profiling. This list is the remaining scope, not a list of completed features.

The facing transform is included before hierarchical interruption blending, so interrupting a turned pose does not snap the body back to front. Props derive orientation from the blended root matrix. Stationary-leg regression assertions exclude actions with an intentional facing turn; their full skeleton is still checked for transition continuity and convergence.

## First globe validation checkpoint

The refined globe sequence rendered 94 frames from three angles (282 views) without clipping. Attachment checks sampled 745 frames; maximum wrist-anchor error was 5.96e-8. All 121 ordered skeletal transitions and 363 facial cases passed continuity checks. The approved neutral image remained effectively unchanged (RGBA MAE 8.95e-8).

A selected original-versus-native globe pose comparison still fails the existing identity gate (silhouette IoU 0.489, RGB MAE 0.385). The comparison independently fits bounding boxes and includes the different base character shapes; it is not a per-prop score or time-aligned choreography test. It did expose the initial undersized globe and insufficient body turn, both corrected. Hand contact, detailed pose matching, and choreography fidelity remain review work. Reports are in `Baselines/2026-09-05-props/`. Runtime 120 Hz presentation remains unverified; this pass has not resolved the existing pacing issue.

## Coconut juggling checkpoint

`Action.swift` owns the shared action catalog. `CoconutJuggle.swift` coordinates three spinning coconuts, alternating hand targets, catches, follow-through, final catch absorption, and stow over the original 6.7-second duration. Flight follows parabolic height/depth arcs; Hermite hand dwell matches the release and catch velocities. The flight depth clears the protruding 3D face. The two-coconut opening and closing holds remain stylized and need finer finger wrapping.

`PropGeometry.swift` builds reusable indexed geometry by prop kind. Coconuts have a slightly irregular ellipsoid shell and a derivative-filtered procedural fiber/grain material with three pores. They use the existing MSAA and shared soft-shadow pipeline. Character material parameters remain unchanged.

The routine rendered 102 frames from three angles (306 views) without clipping. At 120 samples per second, minimum coconut center separation was 0.450 model units for a nominal diameter of 0.400; sampled airborne head clearance was 0.101. The head check uses 4,347 deformed surface points and a conservative prop radius; it does not cover every body surface or every possible interruption. Maximum solved-wrist handoff position discrepancy was 0.00351. A finite-difference check of authored hand/flight velocities passed with maximum discrepancy 0.00369.

Selected original frame 30 and native frame 51 are compared as a visual diagnostic, not synchronized motion: silhouette IoU 0.490 and RGB MAE 0.368 still fail the near-identity gate. The approved fan character, hand poses, and individual coconut phases differ. Original fidelity is unfinished even though numerical attachment and separation checks pass.

Offline timeline rewinds now clear future skeletal transition poses, consistent with prop and facial motion state. This prevents a later action's end pose contaminating earlier preview frames.

All 144 ordered action transitions and 432 facial cases pass, including a dedicated rewind regression. Neutral appearance remains effectively unchanged (premultiplied RGBA MAE 8.95e-8). Reports and the selected original/native/diff image are preserved under `Baselines/2026-09-05-juggle/`; full three-angle playback is `Validation/FanActions/juggle.gif`.

To reproduce the selected comparison:

```sh
swift -module-cache-path .build/clang-cache Scripts/crop-prop-comparison.swift Validation/FanActions/juggle-51.png Validation/Original/Juggle/frames.png 30 0 Validation/Juggle
swift -module-cache-path .build/clang-cache Scripts/compare.swift Validation/Juggle/native.png Validation/Juggle/Comparison Validation/Juggle/original.png
```
