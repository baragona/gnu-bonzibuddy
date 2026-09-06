# Headphone surface contacts — September 5, 2026

Headphones now describe contact with the outside of each cup. `HandAnatomy` resolves the wrist from the character's palm length and depth, and the hand faces inward with fingers curled over the cup tops. Surface grips rotate the thumb curl axis with the posed hand, including inverted carrying. The headset geometry, cheek fit, lighting, and persistent wearable behavior remain the same.

The hands withdraw sideways before lowering after placement; removal approaches from below before moving inward. This avoids the previous direct rest-pose blend through the cup shells. It is an authored transfer path, not an automatic collision solver.

This is the first implemented part of the proposed shared contact architecture. Other routines still use wrist targets. The rest of the skeleton mapping, general collision avoidance, finger surface constraints, and additional character profiles remain work. `HandAnatomy` currently contains the fan model's empirical palm calibration; a second character must supply and validate its own dimensions.

See `collision-comparison.json` for the before/after 120 Hz mesh audit, including residual crossings. Counts are intersecting triangle pairs, not penetration depth or severity. The prior audit's exclusions still apply. Shared resting-hand/body intersections and other routine defects are not resolved by this change.

The preserved renders include front/quarter/left action views and detailed diagnostic views. `original-comparison.png` compares a selected headset-placement pose with original ACS frame 12; `original-comparison.json` records the unchanged likeness gate. The comparison is not time-aligned automatically and does not establish identical motion.

Reproduce numerical contact scanning without overwriting the catalog audit:

```sh
Build/BonziBuddy.app/Contents/MacOS/BonziBuddy --audit-animation-geometry --action Headphones --audit-fps 120 --audit-output Validation/HeadphoneContacts
Build/BonziBuddy.app/Contents/MacOS/BonziBuddy --audit-animation-geometry --action Headphones --audit-fps 120 --with-wearables --audit-output Validation/HeadphoneContacts-wearables
```

Final geometry result: zero detected arm/hand crossings with headphones or sunglasses across 1,696 frames per configuration (3,392 total). Both configurations still report seven body/opposite-arm crossing pairs; these are retained in the comparison rather than filtered out. The older headset transfer had 284/282 left/right hand crossing frames plus forearm crossings in the normal configuration.

Validation passed: routine contracts, headset topology/attachments, wearable scheduling and combinations, 784 ordered skeletal action pairs, and 2,520 facial transition cases. The 213-frame preview covers 639 camera views without viewport clipping. Neutral appearance mean absolute error remains 8.95e-8 against the approved reference. These checks do not prove all possible interrupted transfers are collision-free or verify live 120 fps pacing.

Selected original comparison: silhouette IoU 0.757, foreground RGB MAE 0.239; the unchanged 0.95 / 0.05 near-identity gate still fails. The side grip and clearance are improved, while original pose/proportion fidelity remains incomplete.
