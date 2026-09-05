# Independent sunglasses toggle

The combination sheet shows wave, dance, speech, globe, juggling, banana, and surprise, each from front, quarter, and profile. These are selected poses, not full animation or collision proofs.

`--validate-wearables` passed 1,694 attachment samples across all fourteen other actions. It also checks repeated sets, reversals during both transfer directions, pending reversal cancellation, action requests during transfer, paused body time, waiting for juggling to finish before removal, and cancelling that wait. Maximum head attachment matrix error: 1.19e-7.

The existing 225 ordered action transitions and 765 facial transition cases still pass. The original sunglasses clip attachment and hold/return checks also pass. No character geometry, shader, or material changes were made for this feature.

The right-click and status menus expose Sunglasses as a checked boolean. Return to rest does not unequip it. Prop routines finish before an accessory hand transfer; ordinary gestures pause and resume. The latest action requested during a transfer or its wait is queued until completion. This is a single-accessory coordinator, not a general multilayer animation graph.
