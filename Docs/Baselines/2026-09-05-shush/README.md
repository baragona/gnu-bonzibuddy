# Shush checkpoint

Implements the original Shoosh gesture as a 1.95-second action: raise the left index toward the lips, rest the other hand at the belly, blink three times, and return. No new prop or sound is invented. The character mesh, materials, lighting, and neutral expression remain unchanged.

The routine uses a shared calibrated straight-index target. A new automatic mouth-pucker channel blends through interruptions and respects manual overrides. This is an initial implementation with remaining original-expression and silhouette differences.

## Verification

- Build succeeded. All 19 routine contracts passed (17,306 sampled frames).
- All 841 ordered skeletal transitions and 2,697 facial interruption cases passed. These are continuity checks, not collision tests of every interruption.
- Shush contact validation evaluated 705 rendered samples across three cameras. Maximum target error was 0.003464 character units; maximum fingertip-marker distance to the deformed head surface was 0.033603. Feet had zero matrix drift. Automatic pucker and its manual override passed.
- Separate full-mesh scans sampled 235 frames at 120 Hz without accessories and another 235 with sunglasses and headphones together. Neither detected arm/hand crossings against the body, opposite arm, or active props. The audit excludes coplanar contact, complete containment, same-hand finger intersections, and the separate teeth mesh; zero crossings is not a general physical-correctness guarantee.
- Reviewed front, three-quarter, and both profile hold renders, a blink frame, and the wearable combination. Full three-angle previews rendered without framing clips.
- Existing headphone, wearable scheduler, and hand-contact checks passed.
- The current neutral three-angle render is pixel-identical to the previous rest-contact checkpoint (RGBA MAE and maximum channel error both zero).

## Original comparison

`original-timeline.png` shows the fifteen source frames and start times. The held native pose at 0.60 seconds is compared with original frame 5, whose hold begins at 0.50 seconds. The source spells the animation Shoosh.

The selected-pose diagnostic remains below the unchanged near-identity gate: silhouette IoU 0.57544 and foreground RGB MAE 0.31221. Its foreground/bounding-box normalization includes the native floor shadow, which affects alignment. Visual review confirms the recognizable index-to-lips action and blink timing, but the original has a more puckered expression, different arm/hand proportions, and a different body silhouette. This checkpoint does not claim original visual identity or verified live 120 fps pacing.

The complete repertoire remains unfinished, including other expressive gestures, entrances/exits, and existing prop-contact refinements.
