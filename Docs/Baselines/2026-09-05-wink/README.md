# Wink checkpoint

Implements the original thirteen-frame, 1.80-second Wink: turn the head, close the character’s left eye, hold it closed, reopen, and return. Hands and feet retain the shared rest pose. The original sound cue is outside this visual implementation.

Independent left/right eyelid channels now belong to `FacialIntent`. They share automatic facial blending and transition-distance validation. Renderer composes automatic and manual per-eye values using maximum closure, while global blinking still affects both eyes. No model, shader, material, or external dependency changed.

## Verification

- Build succeeded. All 20 registered routine contracts passed, sampling 17,523 frames.
- All 900 ordered skeletal transitions and 2,880 facial interruption cases passed; the new independent eyelid channels participate in those checks. These tests check continuity, not collision-free interrupted paths.
- Full 120 Hz mesh audits covered 217 Wink samples without accessories and 217 with sunglasses and headphones together. No tested arm/hand crossings were detected. These checks retain the audit’s exclusions for coplanar contact, containment, same-hand fingers, and separate teeth geometry.
- Three-angle previews cover the complete 28-frame performance at 15 fps without framing clips. Reviewed closed and reopened eyes, the headphone combination, and four diagnostic camera views.
- The wearable scheduler suite passed after adding Wink. The neutral three-angle render remains pixel-identical to the previous rest-contact checkpoint (RGBA MAE and maximum channel error zero).

## Original comparison

`original-animation.json` preserves the source metadata and asset hash. `original-timeline.png` shows all thirteen reference frames. Native frame 12 (0.80 seconds) is compared with original frame 6, whose closed-eye hold begins at 0.65 seconds.

The initial head turn was too small in visual comparison. Increasing peak yaw from 0.30 to 0.50 radians makes the head gesture more faithful. The whole-image diagnostic nevertheless changed from IoU 0.67018 / RGB MAE 0.26260 to IoU 0.65330 / RGB MAE 0.26777. Both fail the unchanged near-identity gate (IoU >= 0.95, MAE <= 0.05). The native shadow affects foreground bounds, and the preserved fan model differs in face/body proportions, eyelid contour, and resting arm silhouette. This is not an original-identity claim.

Live 120 fps pacing and the complete original repertoire remain unverified/incomplete. The 120 Hz scans are offline animation samples, not frame-rate measurements.
