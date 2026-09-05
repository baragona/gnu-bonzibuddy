# Animation reference provenance

The frame mapping was inspected from `build/www/js/script.min.js` in:
https://github.com/BonziWorld543/BonziWORLD/blob/main/build/www/js/script.min.js

Archive downloaded from https://codeload.github.com/BonziWorld543/BonziWORLD/zip/refs/heads/main on September 4, 2026. The downloaded JavaScript was read as text, not executed or incorporated into the app. `animation-mapping.txt` retains the relevant frame-index definitions for review.

The archive's purple sprite sheet and `original-sheet.png` have the same SHA-256:
`480f0bca2092c13417946b7a62fbd8ac3520b83404d3ca0c9629ba89de83b82f`

The mapping identifies shrug frames 40 through 50, a hold on frame 50, and a reverse sequence back to idle. The community client's tick interval is 1/15 second. This does not authenticate the original Windows application's exact frame durations. The macOS animation uses that 15 Hz reference sequence with continuous interpolation, a locally chosen hold length, and hand-authored 3D poses. It is not an exact motion capture or a completed animation match.

`Scripts/extract-animation-reference.swift` reproduces the reference crops. `Scripts/compare-animation.swift` compares fixed-canvas poses without per-frame recentering. The reference imagery is excluded from the app bundle.
