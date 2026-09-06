# Hug: torso-relative contact and pose-study follow-up

The embrace now follows upper-body roll and breathing through shared
torso-relative hand targets. Baseline arm directions and finger-curl axes
use the same frame. The thumbs fold across the palms, the upper body rocks
with the arms, and the hands follow revised approach and withdrawal paths.
The original 3.64-second played duration is preserved; see the previous
[draft reference timeline](../2026-09-05-hug-draft/played-timeline.json).

This is still an unfinished hug. The hands and forearms remain too widely
separated compared with the original compact self-embrace. Shoulder skin
folds and brief hand/arm/body crossings remain. The new offline pose-study
tool helped investigate these contacts but is not a runtime contact solver.

Verified evidence:

- Build and routine contracts passed: 23 registered routines, 18,489 samples.
- All 1,089 ordered skeletal transitions and 3,465 facial cases passed.
- All 29 hand-joint matrices stayed stable in torso space through five held-pose samples; maximum matrix drift was 0.000001565. The nine mesh vertices with exclusively hand-joint weights had maximum GPU position drift of 0.000000508. Other hand vertices contain small non-hand influences and are covered by the full mesh scan, not a rigid-hand assertion.
- All 438 samples retained fixed ankle/toe matrices. Pelvis travel was 0.02343 model units.
- Wearable lifecycle, headphone contacts, existing calibrated hand contacts, Shush, wink motion, and wink brow regressions passed. Open-eye Idle remains pixel-identical to the approved baseline.
- An empty offline hand patch at 0.8 seconds produced exactly the same audit frame as the full sequential scan.
- Held, rocking, release, and worn poses were inspected from front, three-quarter, and left views; the GIF preserves the motion for review.

The plain and worn 120 Hz scans each found five crossing-pair categories.
The summed triangle-pair count fell from 131,292 in the earlier draft to
8,740 in this candidate. This is a diagnostic count across time, **not** a
penetration-depth measurement or proof that all remaining contacts are
acceptable. The retained candidate has these unresolved peaks:

| Pair | Peak triangle pairs | Time |
| --- | ---: | ---: |
| Left hand / right hand | 50 | 3.542 s |
| Left hand / right upper arm | 181 | 3.000 s |
| Left upper arm / body | 86 | 0.458 s |
| Left upper arm / right hand | 98 | 3.017 s |
| Right hand / body | 157 | 3.250 s |

The original comparison uses source frame 6 (held from 0.60–1.20 seconds)
and native frame 12 (0.80 seconds). Silhouette IoU is 0.51457 and RGB MAE
is 0.34064. The near-identical gate fails, and these metrics are worse than
the earlier draft's 0.52585 / 0.32649 despite the improved contact counts.
The comparison includes bounding-box effects from the floor shadow; it
does not establish perceptual identity. Compact arm wrapping and original
proportions remain visual work, independently of the new motion controls.

Next work should address the compact embrace and remaining contact paths,
then repeat original comparisons and whole-clip scans. The wider repertoire,
general character profiles/contact solving, and live 120 fps pacing remain
outside this checkpoint's completion claims.
