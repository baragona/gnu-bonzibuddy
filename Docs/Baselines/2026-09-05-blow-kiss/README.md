# Blowing a kiss checkpoint

Implements the original 2.08-second BlowKiss: raise the left hand to the mouth, rotate it palm-up beneath the chin, hold the blown kiss, and return. The approach includes the original blink and a puckered mouth. The source contains no heart prop; original sound cues are outside this visual implementation.

The hand uses shared palm calibration, independent fingers-together and thumb-fold controls, and an authored elbow-bend preference. These belong to hand intent and the rig rather than renderer-specific action branches. The approach travels forward and outside the torso before settling toward the lips. Direction magnitude is normalized when blending an elbow preference. Existing routines retain their default finger articulation and elbow preference.

## Verification

- Build succeeded; all 21 registered routine contracts passed across 17,774 samples.
- All 961 ordered skeletal transitions and 3,069 facial interruption cases passed.
- Full-mesh audits sampled 251 frames at 120 Hz without accessories and another 251 with sunglasses and headphones. No tested arm/hand crossings were detected. Audit limitations still include containment, coplanar contact, same-hand finger intersections, separate teeth geometry, and unsampled interrupted paths.
- Full three-angle previews cover contact, release, return, and combined wearables without framing clips. Four-angle diagnostic poses were also rendered. The included GIF is a 15 fps offline preview, not a live performance measurement.
- Existing headphone, wearable-scheduler, hand-contact, shush, smooth-wink-head, and unilateral-brow checks passed after the shared hand changes.
- Neutral three-angle rendering remains pixel-identical to the rest-contact checkpoint.

## Original comparison

Native frame 9 (0.60 seconds) is compared with original frame 5 (held contact begins at 0.50); native frame 20 (1.33 seconds) with original frame 12 (release hold begins at 1.28). Original metadata, source hash, all frame timings, and both selected-pose comparisons are retained.

The original’s release hand sits directly beneath the chin. Raising and bringing the native palm inward improved that gesture in visual review, while the whole-image diagnostic slightly worsened: release IoU 0.67355 to 0.66371 and RGB MAE 0.28182 to 0.28417. Contact IoU is 0.52700 and RGB MAE 0.34354. Both fail the unchanged near-identity gate (IoU >= 0.95, MAE <= 0.05). Native shadows affect foreground normalization; the approved fan model also differs in body proportions, mouth silhouette, arm proportions, and free-hand placement. This is an implemented, collision-audited performance with remaining fidelity differences, not an original-identity claim.

The wider visual repertoire and verified live 120 fps presentation remain incomplete.
