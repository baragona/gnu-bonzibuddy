# Writing checkpoint — September 5, 2026

Adds indexed pad/pencil geometry, retrieval, repeated strokes, raised-pencil pauses, and stow. The pad has white paper, a yellow binding, and a globe-decorated brown back. Its frame determines the pencil contact point and supporting-hand target. Geometry totals 436 vertices and 218 triangles.

The writing tip stays within 2.22e-8 units of its intended paper clearance in 61 contact samples. Hold-boundary hand/pencil positions match, and a new action waits for the stroke and stow to finish. These are authored contact checks, not proof of finger contact or collision-free motion.

Normal playback and a ten-second hold with both accessories rendered 852 views across three angles, with no clipping. The catalog now has 20 actions; 400 action pairs and 1,320 facial transitions pass. Wearable regression checks cover 2,178 samples. Approved neutral preservation MAE remains 8.95e-8.

Selected original-image comparison: silhouette IoU 0.7029, RGB MAE 0.2780. This fails the unchanged near-identical gate. Pose, gaze, pad angle and proportions still differ. Further work includes accumulated ink, dedicated WritePre/WriteOnce/WriteOnceAgain/WritePause variants, Writing/WritingReturn variations, and refined finger contact. Live 120 fps presentation remains unverified.
