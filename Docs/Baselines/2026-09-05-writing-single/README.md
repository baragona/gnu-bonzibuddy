# Single writing passes — September 5, 2026

Adds Write Once (1.45-second stroke pass) and Write Again (1.20 seconds), following the extracted original segment durations. Both reuse the existing retrieval, stroke, lowered pause, reversible exit and stow. Interactive selection holds only the paused portion after the pass; it does not repeat writing. Compatible requests enter after retrieval, and an active single pass completes before switching variants.

Tests cover stable held pause, repeat from an already-held pad, requests during the pass, stow, shared contact and existing reversal/cancellation cases. Two ten-second-held previews rendered 1,086 views across three angles without clipping, one with both accessories. The expanded catalog passes 529 skeletal action pairs, 1,725 facial cases and 2,541 wearable samples. Neutral preservation MAE remains 8.95e-8.

Selected WriteOnceAgain comparison: silhouette IoU 0.6952, RGB MAE 0.2818, failing the unchanged near-identical gate. Stroke segment durations match the source, but retrieval uses the existing adapted 1.90 seconds rather than WritePre's original 1.45 seconds. Geometry, gaze, hand contact and broader pose fidelity still need refinement. Accumulated ink, Writing/WritingReturn variations, other missing routines and live 120 fps pacing remain unfinished.
