# Wink head-motion correction

The previous wink yaw combined a head-turn track with eyelid closure. This added another turn as the eye closed and reversed it as the eye opened. An intermediate eased key also divided the return into two slowing/accelerating segments. Together they produced the reported stuttering motion despite passing pose-continuity tests.

The head now travels continuously from 0.10 to 0.60 seconds, holds through 1.30 seconds, and returns continuously by 1.70 seconds. Peak yaw stays at -0.50 radians. Eyelid timing is unchanged and no longer controls head rotation.

`--validate-wink-motion` samples the actual rig head direction at 120 Hz. Across 217 samples, hold yaw drift is zero; angular speed has no drop before its peak or increase after the peak in either travel interval. The eye fully reopens during the stationary head hold. This catches a different failure from pose-transition continuity.

All 900 skeletal transition pairs and 2,880 facial cases passed. Both 217-frame geometry scans (plain and both wearables) detected no tested arm/hand crossings. The complete three-angle GIF is included for motion review; its 15 fps preview is not a live 120 fps pacing measurement. Original visual identity and the broader repertoire remain unfinished.
