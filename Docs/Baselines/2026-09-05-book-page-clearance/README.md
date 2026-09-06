# Book page-turn clearance

The old sheet cleared the covers but swept back through the character. The book now tilts toward horizontal and moves forward before the turn, then settles back into the reading pose. The turning hand follows the lower corner in the sheet's frame, including its curl and rotation. The return still waits until the turn and settling motion finish.

Depth testing, MSAA, and the common color/shadow deformation remain unchanged. This is a geometry and choreography correction, rather than a draw-order override.

Validation:

```sh
bash Scripts/build.sh
Build/BonziBuddy.app/Contents/MacOS/BonziBuddy --validate-read --render-page-turn
Build/BonziBuddy.app/Contents/MacOS/BonziBuddy --validate-routines
Build/BonziBuddy.app/Contents/MacOS/BonziBuddy --validate-fan-actions --action Read
```

The collision regression intersects skinned character triangles with the deformed sheet strips at 120 Hz throughout the 0.8-second turn, including visibility scaling through PropMotion. It checks the sheet's back surface against the unmorphed skinned character; facial morphs and arbitrary action interruptions are outside this check. The existing cover-plane, foot-grounding, held-return, and accessory-handoff checks remain in place.

Four camera views are rendered at 800×640 during the turn. Representative front, quarter, and left views are saved here. This checkpoint does not establish original animation identity or full-body collision avoidance for every routine.

Result: zero sheet/character triangle intersections across 97 timeline samples; minimum page-block clearance 0.01015 in book-local units. The full 176-frame, three-angle reading preview had zero clipped views. Reading's grounding and queued return/accessory checks passed.
