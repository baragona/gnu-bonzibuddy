# Code quality pass

Scope: restore a buildable source tree and harden offline pose-study contracts.
The unfinished vine entrance integration was removed from compilation and saved
locally in `Validation/Deferred/vine-entrance-wip.patch` plus `ActorPlacement.swift`.
The committed vine asset remains available. Entrance choreography is still pending.

- Native patch loading rejects unknown/null fields and degenerate orientations.
  Orientation overrides must supply both fingers and palm; this replaces a
  frame-dependent runtime precondition with a load-time error.
- The search script validates sample lists, vector coordinates, bounds and steps
  before launching an audit. Importing it no longer starts a search.
- Completed trials and the initial best result survive a later candidate failure.
- Paths resolve independently of the caller's working directory.

Validation: release build passed; 23 routines / 18,489 samples passed; five Python
regression tests passed. Four malformed native patch cases returned exit code 1
with descriptive errors, and an empty patch completed a real Hug GPU audit.
Fresh front/quarter/left neutral render is pixel-identical to the approved rest
baseline (maximum channel difference and mean error both zero).

This pass does not establish original visual fidelity or full collision safety.
Renderer/FanRig decomposition, shared character calibration, and validation-tool
organization remain candidates for a separate architectural refactor. No new
animation or change to normal playback/rendering is included.
