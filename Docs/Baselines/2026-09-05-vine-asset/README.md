# Vine asset and source review

The extracted Show sequence has 27 frames at 100 ms each (2.70 seconds),
and Hide has 26 (2.60 seconds), with no frame branches. Show approaches
from a very small distant silhouette on a leafy vine, grows toward the
viewer, brings both feet forward, releases, and lands in small white dust
puffs. Hide turns away, crouches, catches the descending vine, and recedes
to an empty frame. The original base-frame contact sheets and metadata
are preserved here. Some source image records have vertical offsets;
use the metadata when authoring placement, not just atlas cell dimensions.

Implemented in this checkpoint:

- A capped, tapered stem with three closed, curved leaves: 1,536 vertices and 2,640 triangles.
- A typed bend in radians, clamped to ±2.5, using a constant-length circular arc with a fixed grip origin. Leaves follow their attachment frames.
- Shared Metal color, soft-shadow, and geometry-audit deformation; existing 4× MSAA remains enabled.
- An asset-only rendering switch for previews, retaining the prop scene and shadows.

The GPU test passed 124 bend samples, including both directions, straight,
and values near zero. Maximum vertex error against the double-precision
reference was 0.000000748 model units; maximum grip-origin drift was
0.000000248. Sixteen views were rendered, and front, quarter, and side
views were inspected. The side views show the leaves' thin geometry;
their orientations can be adjusted during the flight's visual matching.
Existing routine contracts passed and open-eye Idle remained pixel-identical
to the approved baseline.

This is an asset checkpoint, **not an implemented entrance or exit**.
It has not passed an original-pose image-diff gate. The source establishes
the green stem/leaf design and broad choreography; final scale, grip fit,
leaf placement, flight, landing dust, and appearance/disappearance timing
still need a complete scene comparison.

The next integration needs a shared actor placement channel, including
airborne translation/orientation and the source's distance scaling, without
stretching the planted-foot solver. Attached wearables and held props must
follow that placement. Entrance/exit presence must persist after an exit
and remain recoverable through the menu bar. Interruptions and accessory
handoffs must preserve the actor's placement instead of jumping back to
the desktop pose. Those lifecycle requirements remain unimplemented.
