# Self-hug draft checkpoint

This is an unfinished routine, not a fidelity or collision-clearance approval.

The extracted original crosses its arms close to the chest, closes its eyes,
rocks sideways, holds, and returns. Its stored-frame total is 3.74 seconds;
frame 24 branches with 100% probability to frame 26, making played duration
3.64 seconds. `played-timeline.json` records the actual path. The reference
contact sheet labels storage-order times, including the skipped frame.

The native routine adds shoulder protraction through a shared hand-intent
channel, opposite-arm palm targets, independent entry/release weights, eyelid
closure, a small smile, head rocking, and pelvis sway with fixed feet. Its
hand trajectories and skin contacts need further refinement. The original
arms are more closely stacked, its hands are mostly hidden around the upper
arms, and its body leans more as a unit. Moving our targets inward improved
the side profile but increased intersections; the current mesh/IK solve does
not yet produce the required compact embrace.

Validation of this exact draft:

- Build passed. Routine contracts cover 23 registered routines and 18,489 samples.
- All 1,089 ordered skeletal action pairs and 3,465 facial cases passed transition checks.
- All 438 Hug samples at 120 Hz retained identical ankle/toe matrices; pelvis travel was 0.02343 model units.
- Wearable lifecycle, existing calibrated hand contacts, and headphone checks passed.
- Full 438-frame geometry scans, both plain and with sunglasses/headphones, found eight crossing-pair categories. See the two geometry summaries for times, spans, and triangle-pair counts. These are failures to resolve, not intended contact exemptions.
- Front, three-quarter, and left previews were inspected for the held pose and release. Both accessories remain attached in the worn preview.
- The open-eye Idle image is pixel-identical to the approved rest baseline.
- The selected original comparison uses original frame 6 (held from 0.60 to 1.20 seconds) and native frame 12 (0.80 seconds). Silhouette IoU is 0.52585 and RGB MAE is 0.32649; the unchanged near-identical gate fails. The metric includes bounding-box effects from the native floor shadow and is not a perceptual identity test.

Next work: solve the compact upper-arm/hand contacts and the shoulder skin
fold, route entry and release without opposite-hand crossings, then repeat
the full geometry scans and original comparison. Passing lifecycle checks
does not establish correct choreography, collision avoidance, or live 120 fps.
