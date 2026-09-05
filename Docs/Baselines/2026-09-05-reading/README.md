# Reading checkpoint — September 5, 2026

Adds a seated stance, hinged hardcover book, curved page turn, and authored stow/stand sequence. Interactive action and accessory requests wait for the page gesture and return sequence to finish.

Normal and held reading (with both accessories) rendered 1,614 views across front, three-quarter, and left cameras, with no clipping. The headphone performance rendered another 639 views after the shared finger-grip change. Wearable checks cover 1,936 samples across 16 body actions, plus 21 rendered combination views. All passed.

The sampled lowest foot surface is -0.92056 against ground -0.92; seated minimum is -0.91759. These are sampled grounding checks, not comprehensive collision tests.

The selected original reading comparison has silhouette IoU 0.7243 and foreground RGB MAE 0.2848, failing the unchanged 0.95 / 0.05 near-identical gate. Differences remain in proportions, cover angle, hands, feet, and gaze. Approved neutral render preservation MAE is 8.95e-8. Do not treat the comparison as proof of original animation identity.

Reading lookup variants and reading aloud remain unfinished. Immediate speech synchronization can still interrupt a prop routine. Live 120 fps pacing remains unverified.
