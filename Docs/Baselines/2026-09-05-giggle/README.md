# Giggle checkpoint

Implements the original 22-frame, 2.30-second Giggle: develop a broad grin, close the eyes, make five small laugh pulses, then relax and return. Hands retain the shared resting pose; the pelvis moves downward while the feet remain planted. Eyelids, smile offset, and slight bilateral brow lowering use shared facial channels. Original sound cues are outside this visual implementation.

The extracted reference’s opaque head-top row changes from 40 at rest to 42/43 during the repeated poses, while the lowest opaque foot row remains 150. This supports small downward pulses, rather than floating the whole character. The sampler follows the repeated three-pose timing, with downward peaks at 0.40, 0.70, 1.00, 1.30, and 1.60 seconds.

## Verification

- Build and all 22 routine contracts passed (18,051 samples).
- All 1,024 ordered skeletal transitions and 3,264 facial cases passed.
- `--validate-planted-feet --action Giggle` measured zero ankle/toe matrix drift across 277 samples while the pelvis traveled up to 0.037 character units. The reusable check also passed Chest Beat.
- Separate 120 Hz full-mesh scans covered 277 frames without accessories and 277 with sunglasses and headphones together. No tested arm/hand crossings were detected. The audit retains exclusions for coplanar contact, containment, same-hand fingers, separate teeth, and unsampled interruptions.
- Reviewed the full three-angle preview and wearable combination. Four diagnostic camera views were rendered. The GIF runs at 15 fps for offline review; it is not a live pacing measurement.
- Neutral three-angle rendering remains pixel-identical to the rest-contact checkpoint.

## Original comparison

Native frame 6 and original frame 4 both sample 0.40 seconds. The reference timeline and source metadata/hash are preserved. Increasing the smile from 75% to 100% at the default neutral setting improves the broad-grin intent. Silhouette IoU remains 0.68197; foreground RGB MAE changes from 0.28687 to 0.28612. The unchanged near-identity gate still fails (IoU >= 0.95, MAE <= 0.05).

The approved fan model differs in body proportions, arm/rest silhouette, closed-eyelid contour, and toothy-mouth shape. Native shadows also affect the diagnostic foreground bounds. This implements the performance with measured planted feet, without claiming original visual identity. The complete visual repertoire and live 120 fps pacing remain unfinished.
