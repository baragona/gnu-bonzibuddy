# Vine entrance draft

The `Vine Entrance` action implements a 2.70-second first pass at the original
Show sequence: distant approach, overhead one-hand grip followed by a second
hand, backward-leaning feet-forward swing, release, landing crouch, dust puffs,
and return to neutral. The indexed vine uses the shared shader deformation;
dust uses small closed polygon meshes anchored to the stage.

`ContinuousTrack` uses shape-preserving cubic travel curves. Intermediate keys
retain velocity, while extrema and endpoints settle without overshoot. The
existing eased gesture tracks are unchanged. `RoutineEntryPose.authored` permits
an entrance to start away from rest; endpoint/out-of-range contracts still
require rest, and every sampled entry channel remains validated.

Original timing evidence is the previously extracted `Show` sequence in
`../2026-09-05-vine-asset/original-animations.json`, SHA256
f3d4425238b5f68b4d41ed5be271d2f4118a245baf808a62dc1a9e6e619b2f95.
Stage travel keys were informed by the purple-body bounds, then reviewed in
front/quarter/left renders against the original contact sheet.

This is not a finished likeness or collision-safe animation. The full geometry
scan includes intentional hand/vine intersections and hand/dust overlaps, but
also unwanted hand/arm/body and opposite-arm crossings. The grip marker check
measures the posed palm reference against its target; it does not prove a fitted
finger surface. The two pale chest patches exposed by raised arms also appear
in the imported source T-pose and remain part of the approved model; a render
without the separate tooth mesh confirmed they are not detached teeth.

The generic border detector counts the vine exiting the top edge. Its clipped
view count is not evidence that character geometry is within bounds. The
selected image diff includes vine and floor shadow and is a diagnostic,
not an animation-wide correspondence measure. Its strict likeness gate fails.

The entrance currently plays as an explicit action. A visible-to-entrance
transition uses the existing pose blend; persistent hidden/shown lifecycle,
exit choreography, and automatic entrance on showing the panel remain pending.

Validation results for this draft:

- Release Swift build and final Metal compilation/render passed. Continuous-track
  regression: 1,313 bounded samples; maximum finite-difference velocity jump
  0.00298. Run by compiling `ContinuousTrack.swift` with
  `Scripts/check-continuous-track.swift`.
- 24 routine definitions / 18,814 samples; 1,156 ordered action transitions /
  3,672 facial cases passed. Fresh neutral output is pixel-identical to the
  approved rest baseline.
- 325-frame geometry scans at 120 Hz with and without both accessories. The
  worn scan additionally finds upper-arm/headphones and forearm/sunglasses
  crossings. These are unresolved and are retained in the evidence.
- 98 palm-marker samples: maximum target error 0.003464 model units.
- At 1.8 s, selected-pose IoU 0.3931 and foreground RGB MAE 0.3766; strict
  likeness gate fails. Before the lean/vine-angle adjustment these were 0.3659
  and 0.3793. This modest diagnostic improvement does not establish a visual match.
- Final entrance preview: 42 frames, three angles, 25 border detections including
  the vine. The dust material was changed after geometry validation to a narrow
  bright-white lighting range; final color renders were inspected. Geometry and
  choreography were unchanged by that material-only correction.

Next corrections: reduce the right-arm route through the face/accessories,
separate opposite hands/forearms at the grip, align dust onset more closely to
2.2 s, and finish the hidden/shown state machine before implementing Hide.
