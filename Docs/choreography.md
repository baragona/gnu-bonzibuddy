# Choreography and props

Implementation in progress; the complete visual-repertoire goal remains open.

`Routines.swift` samples continuous hand intentions, body facing, head motion, gaze, and prop cues from an action's elapsed time. A routine owns its reveal/hold/stow beats. `FanRig` turns wrist targets into two-bone IK and blends palm/finger intentions with the approved rest pose. Existing actions retain their current reference curves.

`PropMotion` resolves prop anchors after the rig has evaluated and blended its pose. Semantic wrist/head attachments support offsets in blended character axes or axes that rotate with the joint. Rigid attachment frames remove skeletal scale and shear. It preserves outgoing props during interruption and contracts them over 0.20 seconds. This is a first interruption policy; held books, headphones, and thrown objects will need dedicated return/release behavior rather than assuming every prop should contract.

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

Refine banana and miss variation; refine sunglasses finger contact; coconut headphones; butterfly interaction; seated book reading; writing pad/pencil; bamboo mailbox/letter variants; vine and surfboard movement/entrance/exit; chest beating/backflip; hugs/kisses/giggles/shushing; directional presentations and explanations; richer facial/gaze/idle sequences. Each needs actual geometry where applicable, reference-based choreography, clean entry/return/interruption behavior, multiple-angle review, and runtime profiling. This list is the remaining scope, not a list of completed features.

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

## Shared routine architecture and banana work

See [architecture boundaries and extension points](architecture.md#routine-and-prop-boundaries). Playback sampling is now read-only, new routine timing is registered centrally, hand targets/attachments use semantic body parts, and facial channels blend together. Prop scene state is separate from Metal; typed peel/fruit parameters are packed only by the renderer. Both shadow and color passes share deformation.

The first banana implementation exercises two separate polygon assets: a curved fruit with a capped shortening surface, and three thick peel ribbons with independently animated closed/open shapes. The original Banana sequence is 7.20 seconds; BananaMiss is 11.33 seconds, including its long waiting/looking beats. The sampler coordinates two bites/chewing or a missed fruit launch, then a peel toss and return. A reusable grip channel supplies the hand curl.

The initial three-angle review exposed overlong peel ribbons, incorrect inner-surface orientation, a bite positioned too far in front of the face, and clipping during the peel toss. Those were adjusted. Detailed lip contact, the original's very wide mouth opening, finger wrapping, material matching, and object-specific interruption/stow still need work. These are first implementations demonstrating the shared interfaces, not finished visual matches.

```sh
Build/BonziBuddy.app/Contents/MacOS/BonziBuddy --validate-routines
Build/BonziBuddy.app/Contents/MacOS/BonziBuddy --validate-fan-actions --action banana
Build/BonziBuddy.app/Contents/MacOS/BonziBuddy --validate-fan-actions --action 'banana miss'
```

The architecture checkpoint samples 3,776 routine frames and 5,400 prop cues. Semantic attachment, rigid-frame, camera-change, playback-seek, globe-attachment, and juggling-contact checks pass. Banana and Banana Miss rendered 109 and 171 frames respectively from three cameras (840 views), without clipping. Neutral appearance remains effectively unchanged (RGBA MAE 8.95e-8).

A selected first-bite comparison (original frame 18, native frame 30) has silhouette IoU 0.767 and RGB MAE 0.281, failing the existing near-identity gate. It remains a whole-character selected-pose diagnostic, not time-aligned choreography or mouth-contact proof. Reports and the comparison image are in `Baselines/2026-09-05-routines/`.

All 196 ordered action transitions and 644 facial interruption cases pass, including the later banana jaw/gaze/smile beats.

## Sunglasses and sustained playback

The fan source already contains a separate glasses object. `Scripts/export-sunglasses.py` exports its 2,944 used vertices and 5,824 triangles as `Resources/Props/FanSunglasses.mesh`, fitting its coordinates to the approved upper-face lift and head proportions. The imported frames, lenses, and temples retain real depth; a material response permits highlights on dark lenses without changing the character's material.

The inspected original `SunglassesContinued` has 52 frames and 12.60 seconds of timing, including putting them on. `SunglassesReturn` has 20 frames and 1.90 seconds. Our complete preview combines those into 14.50 seconds. A reusable hold range spans 1.90–12.60 seconds: selecting Sunglasses in the app keeps this wearing/adjusting cycle active, and **Return to rest** requests the removal sequence. A request during the entrance waits for the glasses to be put on before removing them. Repeated return requests do not restart removal; backward scrubbing remains deterministic.

The geometry's left hinge marker drives a hand socket. A rigid attachment blend transfers the same prop between that socket and the head, preserving identity. The authored adjustment briefly nudges the glasses while the hand reaches their temple. The reference's relaxed expression is approximated with slight eye closure behind the lenses and a small smile offset, both removed on return.

Starting an unrelated action still uses generic interruption/prop retirement. Keeping glasses equipped while independently speaking or gesturing, and more precise fingertip wrapping, remain work. Head-relative hand targets are currently authored in character coordinates; the head attachment itself is resolved from the evaluated rig.

```sh
python3 Scripts/export-sunglasses.py
./Scripts/build.sh
Build/BonziBuddy.app/Contents/MacOS/BonziBuddy --validate-sunglasses
Build/BonziBuddy.app/Contents/MacOS/BonziBuddy --validate-fan-actions --action sunglasses
Build/BonziBuddy.app/Contents/MacOS/BonziBuddy --validate-fan-actions --action sunglasses --hold-seconds 18
```

The sustained 18-second wear-and-return preview renders 300 frames from three angles (900 views), with no clipping. Numerical checks keep the prop held at 100 seconds, preserve the loop seam, accept early/repeated return requests, and remove it after the return. Hand-marker and head-attachment errors stay below 2.4e-7 model units; the return-start matrix jump is below 3.0e-7. All 225 ordered action transitions and 765 facial interruption cases pass, and neutral appearance remains effectively unchanged (RGBA MAE 8.95e-8). These checks do not establish fingertip contact or original animation identity.

The final selected worn-pose comparison (original continued frame 19, native frame 40) has silhouette IoU 0.765 and RGB MAE 0.227, still failing the whole-character near-identity gate. The comparison prompted broader gray lens reflections; it also retains the approved fan character’s different body proportions. Reports and the comparison image are preserved in `Baselines/2026-09-05-sunglasses/`.
