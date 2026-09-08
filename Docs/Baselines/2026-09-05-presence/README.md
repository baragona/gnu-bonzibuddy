# Persistent visibility lifecycle

Presence is now distinct from the selected body animation and equipped
accessories. Hide waits for active prop stow and queued accessory transfers.
Show cancels a pending Hide or, when hidden, waits for transfers and starts the
vine entrance. Requests arriving during that entrance queue behind it. Hiding
preserves accessory intent, and subsequent body requests do not implicitly show
the character.

The AppKit menu controls the same presence state as the renderer. A single timer
synchronizes the panel at the next visibility boundary; the MTKView pauses while
hidden and the status menu retains Show. The renderer independently produces a
fully transparent frame while hidden, so offscreen use does not depend on a
window being ordered out. Body, teeth, props, and floor shadows are suppressed.
New appearances discard stale displayed-pose and retiring-prop history even if
no hidden frame was rendered.

This is a lifecycle implementation, not a completed exit animation. Hide still
stows then disappears. Original Hide choreography and the remaining entrance
contact/likeness corrections are outstanding. No third-party API is involved.

Verification completed before the initial GitHub push: native playback/render
checks passed, with zero hidden alpha and zero paused-Show pose error. The real
AppKit menu target, panel pause/resume, recovery label, and scheduled Hide timer
passed. Same-timestamp queued-Show cancellation retains the hidden state.
