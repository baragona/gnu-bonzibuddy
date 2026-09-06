# Chest-beating checkpoint

Chest Beat adds the original GetAttention performance as a 1.50-second one-shot routine. The extracted timeline has fifteen 100 ms frames and one terminal zero-duration frame. Its continued/return entries are one-frame placeholders. Alternating swing tracks bring each hand across the upper chest while the other reaches outward. A small pelvis sway keeps the feet planted through the existing leg solve.

HandIntent now has a separate fist amount. The generic rig aligns finger bases, curls them, and wraps the thumb across the palm. Prop grips retain their authored spread and curl when fist is zero. Exact fist shape and palm/finger contact remain refinements, especially from the side.

Validation:

- Full routine: 24 frames at 15 fps, front/quarter/left views, zero clipped views, both alone and with both wearables.
- Foot transforms remained fixed across 181 samples at 120 Hz.
- Five alternating beats approached the skinned chest surface within 0.01371–0.02210 model units. The test rejects distances at or above 0.03. Nearest sampled surface distance is a proximity measurement, not proof against penetration.
- Routine, mail, reading, writing, and clap-contact checks passed after the rig change.
- All 784 ordered action pairs and 2,520 facial transition cases passed their continuity checks.
- Independent wearables passed 3,146 body-action samples and 21 combination views.
- Neutral appearance comparison retained premultiplied RGBA MAE 8.95e-8 against the approved reference.

The selected native frame 9 (0.60 seconds) is compared with original GetAttention frame 6. Silhouette IoU is 0.61900 and foreground RGB MAE is 0.29818. This **fails** the unchanged 0.95 / 0.05 near-identity gate. The original's arm extension, body proportions, and compact fists still differ; retain the approved character appearance while refining choreography.

Reproduce:

```sh
bash Scripts/build.sh
Build/BonziBuddy.app/Contents/MacOS/BonziBuddy --validate-fan-contacts
Build/BonziBuddy.app/Contents/MacOS/BonziBuddy --validate-routines
Build/BonziBuddy.app/Contents/MacOS/BonziBuddy --validate-fan-transitions
Build/BonziBuddy.app/Contents/MacOS/BonziBuddy --validate-wearables
Build/BonziBuddy.app/Contents/MacOS/BonziBuddy --validate-fan-actions --action 'Chest Beat'
Build/BonziBuddy.app/Contents/MacOS/BonziBuddy --validate-fan-actions --action 'Chest Beat' --with-sunglasses --with-headphones
```
