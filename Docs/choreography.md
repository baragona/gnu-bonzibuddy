# Choreography and props

Implementation in progress; the complete visual-repertoire goal remains open.

`Routines.swift` samples continuous hand intentions, body facing, head motion, gaze, and prop cues from an action's elapsed time. A routine owns its reveal/hold/stow beats. `FanRig` turns wrist targets into two-bone IK and blends palm/finger intentions with the approved rest pose. Existing actions retain their current reference curves.

`PropMotion` resolves prop anchors after the rig has evaluated and blended its pose. Semantic wrist/head attachments support offsets in blended character axes or axes that rotate with the joint. Rigid attachment frames remove skeletal scale and shear. It preserves outgoing props during interruption and contracts them over 0.20 seconds. This is a first interruption policy; held books and thrown objects will need dedicated return/release behavior rather than assuming every prop should contract.

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

Refine banana and miss variation; refine sunglasses finger contact; refine coconut headphones contact; refine butterfly interaction; refine seated reading and look-up variants; refine writing pad/pencil contact and pause variants; bamboo mailbox/letter variants; vine and surfboard movement/entrance/exit; chest beating/backflip; hugs/kisses/giggles/shushing; directional presentations and explanations; richer facial/gaze/idle sequences. Each needs actual geometry where applicable, reference-based choreography, clean entry/return/interruption behavior, multiple-angle review, and runtime profiling. This list is the remaining scope, not a list of completed features.

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

The inspected original `SunglassesContinued` has 52 frames and 12.60 seconds of timing, including putting them on. `SunglassesReturn` has 20 frames and 1.90 seconds. Our complete preview combines those into 14.50 seconds. A reusable hold range spans 1.90–12.60 seconds: the offline held preview keeps this wearing/adjusting cycle active. In the app, Sunglasses is now an independent checked toggle; turning it off requests removal, while **Return to rest** leaves it equipped. A request during the entrance waits for the glasses to be put on before removing them. Repeated return requests do not restart removal; backward scrubbing remains deterministic.

The geometry's left hinge marker drives a hand socket. A rigid attachment blend transfers the same prop between that socket and the head, preserving identity. The authored adjustment briefly nudges the glasses while the hand reaches their temple. The reference's relaxed expression is approximated with slight eye closure behind the lenses and a small smile offset, both removed on return.

Glasses now stay equipped while independently speaking, gesturing, or performing other prop routines. Transfers reserve the action slot briefly; ordinary gestures resume afterward, while prop routines finish stowing their objects before the transfer starts. More precise fingertip wrapping remains work. Head-relative hand targets are currently authored in character coordinates; the head attachment itself is resolved from the evaluated rig.

```sh
python3 Scripts/export-sunglasses.py
./Scripts/build.sh
Build/BonziBuddy.app/Contents/MacOS/BonziBuddy --validate-sunglasses
Build/BonziBuddy.app/Contents/MacOS/BonziBuddy --validate-fan-actions --action sunglasses
Build/BonziBuddy.app/Contents/MacOS/BonziBuddy --validate-fan-actions --action sunglasses --hold-seconds 18
```

The sustained 18-second wear-and-return preview renders 300 frames from three angles (900 views), with no clipping. Numerical checks keep the prop held at 100 seconds, preserve the loop seam, accept early/repeated return requests, and remove it after the return. Hand-marker and head-attachment errors stay below 2.4e-7 model units; the return-start matrix jump is below 3.0e-7. All 225 ordered action transitions and 765 facial interruption cases pass, and neutral appearance remains effectively unchanged (RGBA MAE 8.95e-8). These checks do not establish fingertip contact or original animation identity.

The final selected worn-pose comparison (original continued frame 19, native frame 40) has silhouette IoU 0.765 and RGB MAE 0.227, still failing the whole-character near-identity gate. The comparison prompted broader gray lens reflections; it also retains the approved fan character’s different body proportions. Reports and the comparison image are preserved in `Baselines/2026-09-05-sunglasses/`.

## Coconut headphones

`HeadphonesGeometry` builds hollow coconut shells with cream interiors, a curved black headband, and an antenna. The shell surfaces have independent inside/outside normals and indexed rims; all parts share the prop color and shadow pipeline. The original reference shows the white interiors while Bonzi holds the headset upside down.

`HeadphonesRoutine` follows the extracted 12.02-second continued sequence and 2.10-second return. It lifts and rotates the headset with both hands, seats it on a rigid head attachment, releases the hands, closes the eyes, and adds a small listening sway. The held range is 2.00–12.02 seconds. The offline held preview retains the listening performance. In the app, Headphones is an independent toggle: it stays on during juggling, speech, and other actions without forcing closed eyes. Return to rest leaves both accessories equipped.

A hold-capable routine marked `finishRoutine` now receives its return request before a sunglasses transfer, so held listening cannot block a toggle indefinitely or lose its headset mid-transfer. The shared wearable queue now also serializes transfers between independently toggled sunglasses and headphones. Taking off either leaves the other equipped.

The procedural mesh and choreography are an initial reference-based implementation. Hand targets remain authored in character space, and finer fingertip contact and frame-by-frame original motion matching need further work.

Validation: 7,852 headset vertices and 14,464 triangles, no reversed or degenerate triangles, sampled carry marker error 0.00347 model units, and head attachment error below 3e-7. The normal and held-with-sunglasses previews cover 516 frames from three angles (1,548 views) with no clipping. All 256 ordered skeletal transitions and 864 facial transition cases pass. The neutral render remains effectively unchanged (RGBA MAE 8.95e-8).

The selected original listening frame 27 versus native frame 100 comparison improved after revising earcup and antenna proportions: silhouette IoU 0.743, RGB MAE 0.251. It still fails the near-identity gate. Reports and selected images are in `Baselines/2026-09-05-headphones/`; these checks do not establish exact original choreography or comprehensive collision avoidance.


The user's tighter-fit revision moves each earcup inward by 0.045 model units and down by 0.015, with matching headband, antenna mount, and hand marker changes. Front, quarter, and profile combination renders confirm the cups meet the cheeks. The shared toggle checks cover both accessories across 1,694 body-action samples, queued reversals/cancellation, and removing one while retaining the other.


## Butterfly interaction

The original ACS `Butternut` sequence has 95 base frames and 10.30 seconds of timing. Its yellow-orange butterfly enters from the left, lands on the extended index finger, stays while Bonzi reaches toward a wing, and departs over his head. `ButterflyRoutine` implements those beats with flight, perch, touch, and return phases. Its small mouth change before departure approximates a blowing gesture; full lip articulation remains unfinished.

The butterfly uses thick two-sided wing meshes with independent thorax rotations, plus a body, antennae, and six legs. Wing patterning is procedural. A shared `MotionPath` carries continuous velocity through flight waypoints; the same prop anchors blend into and away from a semantic index-tip attachment. The marker extends 0.18 terminal-bone lengths beyond the last joint, based on approximately 0.0185 model units of distal mesh extension for a 0.1039 segment. This replaces the first estimate that left a visible gap above the finger.

Pointing exposed a rig bug: fixed-world-axis curls twisted the non-index fingers when the hand pointed upward. The curl axis now follows the authored finger/palm frame. The butterfly validation checks that the index remains above the curled middle finger, along with mesh winding, waypoint velocity continuity, and stable perching. Fine contact remains visual/diagnostic rather than a general collision solver. Independently worn accessories remain compatible.

The plain and both-accessories previews each render 156 frames from three angles: 936 views without clipping. Unique butterfly meshes total 1,295 vertices and 1,488 triangles. Perch attachment error is below 1.6e-7, waypoint velocity mismatch below 0.00134, and the curled middle finger remains 0.248 model units below the index tip at the checked pointing pose. The other index tip stays within 0.171 of the perch center during touching, reaching the wing region; this is not an exact collision/contact proof.

The original-frame comparison prompted a wider/larger butterfly and more olive markings. The final selected pose still fails whole-character near-identity: silhouette IoU 0.629, RGB MAE 0.291. The neutral render is preserved (RGBA MAE 8.95e-8), and 289 ordered action transitions plus 969 facial cases pass. A material regression checks 2,646 gold-colored wing pixels and finds zero changed channels under blink/gaze changes. Reports and representative views are in `Baselines/2026-09-05-butterfly/`.


## Seated reading

The implementation combines the extracted `Read` entrance (4.30 seconds), `ReadContinued` loop (4.75 seconds), and `ReadReturn` (2.56 seconds). Bonzi sits with his soles facing forward, retrieves and opens a brown book with a globe cover, scans the pages, turns a sheet, stows the book, and stands. Selecting Read holds the reading loop; Return to rest requests the return. Read Look Up adds the original’s distinct look-up and conversational hand gestures. Reading-aloud behavior remains unfinished.

`StanceIntent` authors a pelvis offset and semantic foot targets, including foot rotation and knee bend direction. The shared rig solves the legs and blends the stance through its existing skeletal transition path. Stance-changing routines declare that fact so the transition validator does not incorrectly demand stationary leg matrices; `--validate-read` separately checks their targets and sampled foot surface height. Grip curls now use the authored finger/palm directions, matching the earlier pointing fix.

The book has hinged cover/page-block meshes and a separate two-sided turning sheet. A typed page-curl parameter deforms both the color and shadow passes. Held hand targets follow the same cover transforms. Original-frame comparison prompted a larger book across the lap, a revised tilt, and outward-turned feet. Detailed spine curvature and exact finger/page contact remain refinement work.

Menu animation requests now honor a routine's handoff policy: prop routines finish their authored return/stow before the latest queued request starts. Direct `play` remains available for offline previews and current immediate speech synchronization. Reading also declares a return delay during a page turn. Playback exposes the scheduled completion time, so queued actions, accessory transfers, and held previews all wait through the page turn and the entire return.

### Reading look-up variant

`ReadLookUpRoutine` reuses the seated book retrieval and stow geometry, with the original entry/continued/return durations of 4.95, 5.80, and 2.53 seconds. The continued loop includes two open-palm gestures and a return to scanning the book. A return request during either gesture waits until the hand has returned to the cover before stowing. The book retains the same prop identities, stance, lighting, and accessory composition. This is visual choreography; it does not synthesize speech.

The page hinge now translates behind the stationary blocks independently of sheet rotation, preventing the turning thickness offset from crossing the opposite cover. Sampled leaf vertices clear both page-block planes; see [the reading look-up checkpoint](Baselines/2026-09-05-reading-lookup/README.md).

## Writing pad and pencil

Initial `WriteRoutine` combines Write (4.30 seconds), WriteContinued (1.20 seconds), and WriteReturn (1.45 seconds). Indexed meshes include a paper stack, yellow binding, globe-decorated brown back, pencil shaft, wood taper, graphite tip, and eraser. Choreography derives pencil contact and support-hand targets from the same pad frame. Write holds its repeated stroke loop, completes an active stroke before lifting the pencil, and stows both objects before another menu action or accessory transfer. The loop shares its raised-pencil boundary pose. Further work includes accumulated ink, Writing/WritingReturn variations, and exact finger contact.

### Writing pause and resume

Write Pause reuses retrieval and stow while holding the pad and raised pencil. Its half-second attention change follows the extracted WritePause sequence. Selecting it during Write waits for the active stroke to finish and enters directly with the props held. Selecting Write again resumes the stroke loop without retrieval. Write Once and Write Again now perform their respective 1.45- and 1.20-second stroke passes and settle into the held pause. Accumulated ink remains unfinished.

The paused writing hand lowers toward the original chest-level pose, carrying the pencil with it. Resume reverses this half-second motion before entering the writing loop; stow uses the same return to the common grip.

### Single writing passes

`WriteSingleRoutine` composes the common retrieval, one stroke pass, and the paused routine. Write Once uses the original 1.45-second stroke segment; Write Again uses 1.20 seconds. Both hold only the final pause, so a long hold never repeats the stroke. Their compatible entry starts after retrieval when the pad is already held. Requests during the stroke finish the pass before switching. The existing adapted 1.90-second retrieval is shared rather than matching WritePre’s original 1.45 seconds exactly.

## Mailbox — empty check

Initial Mail Empty combines MailCheck (0.90 seconds) and MailCheckEmpty (2.60 seconds). A hollow bamboo barrel grows from a planted post, Bonzi reaches to open its circular door, crouches to inspect it, and reaches back to close it before the mailbox disappears. The barrel, wall thickness, post nodes and leaves are indexed geometry; the banana flag reuses the fruit and closed-peel meshes. The mailbox and door share a frame with a ground-preserving appearance offset. Full-mail retrieval and letter/read/next/return routines remain unfinished. No email service is connected.
