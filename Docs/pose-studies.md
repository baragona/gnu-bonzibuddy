# Offline hand-pose studies

Use these tools to investigate an authored routine with the actual Metal mesh.
They do not alter normal playback, provide runtime collision avoidance, or
establish visual fidelity.

Example study specification:

```json
{
  "action": "Hug",
  "times": [0.8, 1.32, 1.68],
  "pose": {"left": {"palmContact": [0.43, 0.171, 0.28]}},
  "variables": [["left", "palmContact", 2, 0.20, 0.40, 0.02]]
}
```

Each variable is `[side, vectorField, component, lowerBound, upperBound, step]`.
Components 0/1/2 are X/Y/Z. Fields retain the routine's target space and hand
engagement weights. Omitted fields keep their authored values. `time` can
replace `times` for a single sample. Each successive coordinate-search pass
uses a smaller step. The objective sums detected triangle-pair crossings
across the chosen samples; it does not measure depth, anatomical plausibility,
or similarity to the original.

```sh
python3 Scripts/study-hand-pose.py study.json Validation/PoseStudy --passes 3
Build/BonziBuddy.app/Contents/MacOS/BonziBuddy --audit-animation-geometry \
  --action Hug --audit-hand-patch Validation/PoseStudy/best.json \
  --audit-render-time 0.8 --audit-output Validation/PoseStudy/Views
```

The output preserves candidates in `trials.json`, the selected patch in
`best.json`, and its sampled geometry in `best-audit.json`. Render the result
from all four diagnostic views, inspect the whole motion after transferring
the useful adjustments into its sampler, and repeat the full 120 Hz scan
without a patch. A single-time patch overrides contact coordinates directly;
applying it across a full clip also overrides the clip's contact trajectory.
It is not a substitute for authoring entry and return paths.

Input contracts: supply exactly one of `time` or a nonempty `times` list;
samples must be finite and nonnegative. Variables must name existing vector
coordinates, start within their bounds, and use a positive step. Unknown fields
are errors. When overriding hand orientation, supply both `fingers` and `palm`;
the native loader rejects zero or collinear directions before rendering.
This paired override prevents validity from changing with an unpatched,
animated direction. Omit both to preserve the authored hand frame.

The script can run from any directory. Each completed trial and the initial
best result are saved immediately, preserving completed work if a later native
audit fails. Run `python3 Scripts/test-pose-study.py` for input regression checks.
