# Vine grip and arm routing

The entrance hands now curl across the vine instead of along it. Quaternion
interpolation of the finger/palm frame keeps hand orientation rigid through the
reach and release. The shoulders move forward during the overhead grip, then
settle back after release; the release hand trajectory arcs farther in front of
the body. Dust grows earlier so it is visible at the original's 2.2-second beat.

Two offline pose searches kept the authored contacts fixed while adjusting
shoulder offsets and elbow preferences. The first used the old finger direction:
37 candidates reduced summed crossings at 1.55/1.8/1.95 s from 5,595 to 3,059.
After correcting the finger direction, a second search of 47 candidates reduced
its sampled count from 3,340 to 683. These are diagnostic counts including
intentional hand/vine contacts, not penetration depth or a fidelity score.
The selected poses were inspected from front, quarter and left before transfer
to the sampler. Full-clip validation is recorded separately from search results.

The imported mesh, face, colors and normal playback are unchanged. The shared
hand-frame check covers 1,936 frame samples, with maximum orthonormal error
2.384e-7. The original likeness gate and remaining intersections are reported
rather than waived. This work does not implement Hide or persistent visibility.

Final validation:

- Release build passed. 24 routine definitions / 18,814 samples, 1,156 action
  pairs and 3,672 facial cases passed. Neutral front/quarter/left image is
  pixel-identical to the approved rest baseline.
- Full 325-frame, 120 Hz scans: summed non-prop triangle crossings fell from
  116,351 to 18,167. The revised scan with both accessories has the same pairs
  and counts; no accessory crossing was detected. This is limited to the audit's
  region partition and surface-crossing method, not proof of collision freedom.
- Remaining non-prop pairs: left forearm/right hand, both upper arms/body, and
  right hand/body (three frames, peak 276 pairs near 2.058 s). Hand/vine and
  hand/dust intersections are recorded separately.
- 98 hold samples retain maximum palm-marker target error 0.003464 model units.
- Selected 1.8-second image IoU rose from 0.3931 to 0.3987, while RGB MAE worsened
  from 0.3766 to 0.3787. Strict likeness gate still fails. No claim of an overall
  original visual match is made.
- Final plain and worn three-angle clips were rendered, with key front, quarter,
  left and worn swing views inspected. The dust now appears at the landing beat;
  its simple mesh puffs still differ from the original's irregular cloud shapes.
