# Full-mail checkpoint

Mail Full now opens the mailbox, extracts a compact letter with one hand, brings in the other hand after clearance, expands the letter, reads, and stows it. The original MailCheck, MailCheckFull, and MailReturn segments total 6.20 seconds. A hold repeats only reading. The existing mail continuation contract allows Mail Read and Mail Next to reuse the held letter; early requests wait for retrieval, and accessory transfers wait for stow.

MailboxScene shares the empty/full layout. Its stage anchor keeps the mailbox fixed while Bonzi turns toward it. Retiring props use the same grounded coordinate frame and follow camera changes.

Evidence:

- Full routine: 94 frames, three angles, zero clipped views.
- Held routine with sunglasses and headphones: 166 frames, three angles, zero clipped views.
- Mail checks: no stationary-mailbox drift; stored packet radius 0.10477 against the 0.132 aperture; minimum clearance past the barrel during expansion 0.14000.
- Routine lifecycle and attachment checks passed. All 729 ordered skeletal action pairs and 2,349 facial cases passed their continuity checks.
- Wearables: 3,025 action samples and 21 combination views passed.
- Approved neutral appearance: premultiplied RGBA MAE 8.95e-8.

The selected native reading pose (frame 40 at 15 fps) is compared with original MailCheckFull frame 18. The whole-character silhouette IoU is 0.55063 and foreground RGB MAE is 0.28911. This **fails** the unchanged 0.95 / 0.05 near-identity gate. Foreground extraction includes the native floor shadow, so these are broad diagnostics rather than an isolated prop comparison.

Visual review shows the full sequence and props, with remaining differences in crouch/lean, gaze, and letter handling. The letter expands by nonuniform scaling after extraction, not physical crease unfolding. Full hand-mesh collision avoidance is not established. No email content or third-party service is connected.

Reproduce:

```sh
bash Scripts/build.sh
Build/BonziBuddy.app/Contents/MacOS/BonziBuddy --validate-mail
Build/BonziBuddy.app/Contents/MacOS/BonziBuddy --validate-routines
Build/BonziBuddy.app/Contents/MacOS/BonziBuddy --validate-fan-transitions
Build/BonziBuddy.app/Contents/MacOS/BonziBuddy --validate-wearables
Build/BonziBuddy.app/Contents/MacOS/BonziBuddy --validate-fan-actions --action 'Mail Full'
Build/BonziBuddy.app/Contents/MacOS/BonziBuddy --validate-fan-actions --action 'Mail Full' --hold-seconds 10 --with-headphones --with-sunglasses
```
