# Hand direction and intersection audit — September 5, 2026

The audit confirms substantial hand/prop and resting-hand intersections. The rig follows authored hand directions accurately; several authored contact frames, finger shapes, and approach/return paths need correction. This checkpoint adds diagnostics and records the problems; it does not fix the animation poses.

Open [the offline interactive viewer](viewer.html) to inspect hand axes in front, top, and side projections, scrub each routine, and view reviewed renders. Blue indicates wrist-to-middle-knuckle direction, orange the calibrated palm normal, and green the actual index direction. All examples were rendered from front, quarter, left, and right; selected views are preserved here. Full generated views remain in `Validation/GeometryAudit*`.

## Coverage and direction results

All 28 catalog routines were sampled at 120 Hz, once normally and once with sunglasses and headphones equipped: 21,041 poses per configuration, 42,082 total. This is offline sampling density, not a live frame-rate measurement. Idle covers 4.6 seconds and speech 2 seconds; other clips cover their full authored duration.

Across 38,942 fully engaged hand targets, the maximum hand-axis error was 0.0396 degrees and the maximum palm-normal error was 0.0343 degrees. These measure agreement with authored intentions, not anatomical correctness. A perfectly followed target can still point the palm the wrong way for a grip. Blending frames are excluded from these maxima because partial intent weights deliberately retain some underlying pose.

For example, at 1.6 seconds in Headphones, the hand axes point inward at yaw +87.4/-87.4 degrees and elevation 13.8 degrees, while both palm normals are approximately (0, -0.18, 0.98). Fingers cut through the cup shells. The fix needs side-grip contact frames and finger articulation, not only a wrist-position adjustment.

Numbers use the default view's coordinate frame: camera yaw 0, pitch 0.18 radians; +X screen-right, +Y screen-up, +Z toward the viewer. Yaw becomes unstable near a vertical direction; consult XYZ vectors there. Curled index fingers need not follow the hand axis.

## Reviewed findings

Priority reflects visible disruption, not triangle-pair count. Times below identify reproducible examples, not necessarily the maximum count.

| Priority | Routines | Example | Finding / next correction |
| --- | --- | --- | --- |
| High | Idle and common entrance/return poses | Idle 1.400 s | Fingers overlap torso and opposite hand. Establish a clear shared resting contact pose first. |
| High | Read, Read Look Up | Read 5.800 and 9.833 s | Hand passes through cover; closed book passes through forearm during stow. Rework cover grips and transfer paths. The moving sheet `read.page` itself reported no crossings in the full scan. |
| High | Mail Read, Mail Next, Mail Full | Mail Read 4.167 s | Letter panel sweeps through hand during stow. A fingertip near the panel did not ensure whole-hand clearance. |
| High | Write, Write Pause, Write Once, Write Again | Write 0.733 and 1.167 s | Pad crosses forearm/hand during retrieval; pencil grip also needs correction. These variants share the transfer. |
| High | Headphones | 1.600 s | Fingers emerge through cup shells. Introduce proper cup grip sockets and constrained fingers. |
| Medium | Mail Empty, Mail Full | 0.800 / 1.200 s | Hand penetrates mailbox door and extraction region. Separate door-opening, grasp, and pull-out contacts. |
| Medium | Globe | 2.633 s | Supporting finger extends inside globe. Use a surface contact, accounting for finger thickness. |
| Medium | Surprised with wearables | 0.233 s | Raised hand cuts through earcup. Equipped accessories must participate in arm clearance. |
| Medium | Sunglasses | 13.633 s numerical flag | Hand/forearm crosses glasses during removal/stow; needs detailed contact-path review. |
| Lower | Banana, Banana Miss | Banana 2.300 s | Peel crosses gripping fingers; brief forearm/peel flags also occur. Refine fruit/peel grip geometry. |
| Lower | Butterfly | 4.967 s | Touching finger intersects wing. Offset the contact by the finger surface. |
| Lower | Juggle | 0.600 / 1.100 s | Catch contacts account for many flags; reviewed poses look closer to intentional palm support. Apply a small explicit contact tolerance, not blanket collision suppression. |
| Lower | Clap | 0.267 s | Palms oppose coherently, but forearm/chest clearance needs refinement. |
| Lower | Wave with headphones, Dance | Wave 0.500 s | Small upper-arm/earcup or near-shoulder/body flags. Review with connected-shoulder embedding in mind. |

Chest Beat, Look Left, Look Right, Think, Shrug, and Speak primarily inherit the common resting-hand issue in this audit. This is not a clean bill of health for those clips. All actions and detected pairs are included in [crossings.csv](crossings.csv); the grouped discussion avoids counting one shared pose defect as 28 separate defects.

## Method and limitations

The audit reads positions produced by Metal's actual shared skinning, facial morph, and prop deformation functions. It refits triangle BVHs and tests noncoplanar surface crossings between each hand/forearm/upper arm and the body, active props, and opposite arm regions. Simple crossing, coplanar exclusion, BVH query, and refit fixtures run before scanning.

Counts represent intersecting triangle pairs. Spans are the bounding dimensions of crossing points; neither is penetration depth or an automatic severity score. Intended touch, grip, clap, or catch contacts need semantic context and visual review.

The test excludes mixed-region boundary triangles and upper-arm/body crossings within 0.12 model units of the connected shoulder. It does not detect full containment without surface crossing, coplanar overlap, tangencies, same-hand finger self-collision, same-side adjacent arm collisions, floor penetration, or the separate teeth mesh. Sampling can miss events between frames. Arbitrary interruptions, held loops, and rapid wearable-toggle sequences were not exhaustively collision-audited. Previous continuity/proximity checks remain useful but cannot establish nonpenetration.

The next architecture step is a shared contact and clearance layer with per-character anatomy profiles; see [the proposed design](../../character-motion-design.md). Use inexpensive collision proxies during animation and retain this detailed geometry audit offline.

## Reproduction

From the repository root, after `bash Scripts/build.sh`:

```sh
Build/BonziBuddy.app/Contents/MacOS/BonziBuddy --audit-animation-geometry --audit-fps 120
Build/BonziBuddy.app/Contents/MacOS/BonziBuddy --audit-animation-geometry --audit-fps 120 --with-wearables
Build/BonziBuddy.app/Contents/MacOS/BonziBuddy --audit-animation-geometry --action Read --audit-render-time 5.8
python3 Scripts/report-animation-audit.py
```

The report script requires both complete scans and the curated renders listed in its `cases` table. Render those cases with `--audit-render-time`; add `--with-wearables` for the wearable case. Render-only commands preserve numerical scan data. A filtered numerical scan replaces that folder's summary with its subset, so run the complete scans before regenerating the report.

[coverage.json](coverage.json) preserves sample totals and errors; [selected-hand-directions.csv](selected-hand-directions.csv) contains numeric directions for reviewed poses. The viewer includes 10 Hz samples plus each pair's peak frame; raw 120 Hz per-frame JSON remains in ignored `Validation/`. This audit did not evaluate likeness to original sprites or live 120 fps pacing.

Verification: the built executable completed both scans and regenerated the diagnostic views using the exact rendered bone palette. The [neutral appearance comparison](neutral-comparison.json) retained premultiplied RGBA mean absolute error of 8.95e-8 against the approved reference. Report generation asserts complete catalog coverage, 120 Hz data, and frame totals; viewer timelines, linked images, and JavaScript syntax were checked. `git diff --check` passed.
