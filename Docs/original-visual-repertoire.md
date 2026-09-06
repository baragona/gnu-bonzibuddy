# Original visual repertoire

Research date: September 5, 2026. The original's repertoire is substantially broader than our current action catalog. The working tree has twenty-eight action entries, including first globe, juggling, banana, butterfly, reading, headphones, and sunglasses implementations. See [source audit and full animation directory](../References/AnimationInventory/README.md) and [sampled sprite review](../References/AnimationInventory/surfboard-sprite-review.png).

## Evidence levels

**Visual** means sampled extracted sprites were inspected in this pass. **Extracted** means sampled base frames from the mirrored 3.0.7 file were inspected after decoding. **Asset** means a named multi-frame animation was found in the mirrored 3.0.7 file, but its complete choreography and prop appearance have not yet been reviewed. **Catalog** means a community description only. None establishes which original application events invoked every animation.

## Props and large routines

| Routine | Evidence | Our app |
| --- | --- | --- |
| Produce a globe and spin it while watching it | Visual: earlier `Search` / `Searching` sprites | First 3D routine implemented; further matching needed |
| Peel/eat/toss banana, plus a miss variant | Extracted: `Banana` 69 frames; `BananaMiss` 64 frames | Initial 3D routines; detailed mouth contact and reference matching remain |
| Put on sunglasses, pose, adjust them, and remove them | Visual: earlier `Idle2_1`; later continued/return entries also exist | Implemented with sustained wear and removal; finer finger contact remains |
| Coconut-shell headphones, with continued and return segments | Extracted and visually reviewed: `HeadphonesContinued` 60 frames, `HeadphonesReturn` 18 frames | Initial hollow-shell mesh, two-handed pickup, held listening, and removal; finer contact remains |
| Juggling three coconuts | Extracted: `Juggle` 62 frames; exact trajectories still need matching | Implemented; sampled clearance passes, visual fidelity remains approximate |
| Seated book reading, looking up, resuming, and putting away | Extracted: `Read` 31 frames plus related segments | Seated reading/page turn plus look-up/continued gestures and stow/stand; reading aloud remains |
| Pencil-and-pad writing, pausing, repeating a stroke, and returning | Extracted: `Write` 37 frames plus related segments | Initial pad/pencil retrieval, stroke loop, and stow; in-place pause/resume and once/again passes supported; ink and Writing variations remain |
| Bamboo-style mailbox, empty/full outcomes, read a letter, advance, and return | Extracted: separate mail family | Bamboo mailbox empty/full checks; letter read/stow and in-place next-letter gestures; extraction and folding fidelity remain |
| Surfboard entrance, exit, and directional travel | Visual: earlier `Show` / `Hide`; move families in metadata | Missing |
| Vine entrance, exit, and travel | Extracted: later `Show` uses a vine and landing dust | Missing |
| Backflip with a puff at landing | Visual: earlier `GetAttention2` | Missing |
| Chest-beating gesture | Extracted and visually reviewed: `GetAttention`, 1.50 seconds | Alternating fist/arm choreography added; finer contact and reference matching remain |
| Butterfly visit, finger landing, and departure (`Butternut`) | Extracted and visually reviewed: 95 frames | Initial articulated-wing mesh, fingertip perch, touch gesture, and departure; finer choreography remains |

## Gestures, face, and ambient behavior

| Family | Original evidence | Our app |
| --- | --- | --- |
| Point/present in four directions; multiple explanation poses | Directional gesture and `Explain` families in asset; some earlier presentation sprites already tracked | Missing as dedicated actions |
| Greet, wave, congratulate | Named asset sequences; earlier clap sprites already used as reference | Wave/clap approximations exist |
| Shrug, confusion, uncertainty, sadness, pleased reactions, disbelief | Named asset families; earlier confusion/uncertainty sprites | Shrug/surprise exist; some facial components available manually |
| Shush | Shoosh: 15 frames, 1.95 seconds | Authored index-to-lips gesture, free hand at belly, three blinks, and mouth pucker; visual fidelity remains under review |
| Wink | Thirteen-frame, 1.80-second sequence | Head turn and independent left-eye closure/reopening through shared facial channels |
| Hug, blow a kiss, giggle, hands behind back | Named multi-frame sequences in asset | Missing choreography |
| Scout/look around, alert, listening | Named asset families, some placeholders; inspect individually | Thinking and gaze controls cover only part |
| Look up/down/left/right and diagonally, blink while looking, return | Asset has separate directional/blink/return segments | Left/right actions, gaze sliders and automatic blink exist |
| Numerous idle variations and rest poses | Many asset entries; sampled earlier idles show face and gaze changes | One authored idle with breathing/blinking |
| Talking and singing performance | Original-era feature descriptions; speech can combine poses and mouth overlays | Local speech and approximate jaw cycle; no original singing choreography |

## What this implies for implementation

Build a small prop system before adding isolated tricks: hand attachment transforms, independent prop motion, visibility cues, and the same lighting/shadow pipeline as the character. Each routine should have an entrance, a hold or loop where needed, and a clean return. Interruptions must account for any object still in the hands or airborne.

Suggested first group: **globe → banana → sunglasses → book/reading → vine entrance/exit**, followed by juggling, headphones, writing/mail, richer gestures, and ambient routines. This ordering is a project recommendation, not a historical claim. Preserve the approved character appearance.

We should extract original frame timing and review full sequences before matching the motion. Frame counts are not durations; branching and loops matter. The new inventory makes this possible without installing a large editor.

## Scope limits

This is a complete name/header inventory for the inspected file, not a visual certification of every entry or every release. Community references report an unused newspaper routine; keep it separate from shipping behavior until verified. Modern BonziWORLD hats, recolors, memes, and fan-game powers do not automatically belong to the original repertoire. `DoMagic1` / `DoMagic2` names are not evidence of a visible magic act.
