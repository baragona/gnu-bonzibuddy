# Original animation research — September 5, 2026

## Sources and verification

- [Mirrored Bonzi.acs](https://github.com/x8BitRain/BonziRogue/blob/master/Bonzi.acs): downloaded only the character data, not the containing project's software. Embedded extra-data string is `3.0.7`. SHA-256 and all directory entries are recorded in `bonzi-3.0.7.json`. This is a community mirror, not a publisher-authenticated distribution.
- [Smore Bonzi metadata](https://raw.githubusercontent.com/smore-inc/clippy.js/master/agents/Bonzi/agent.js) and [sprite atlas](https://raw.githubusercontent.com/smore-inc/clippy.js/master/agents/Bonzi/map.png): inspected as data. This is the earlier surfboard repertoire. The attached contact sheet samples five positions per selected sequence, compositing the listed image layers. It is visual evidence, not original playback timing or an exhaustive review.
- [Agentpedia catalog](https://agentpedia.tmafe.com/wiki/Bonzi): reports 148 animations, multiple versions, vine versus surfboard differences, and an unused newspaper animation.
- [MS Agent Wiki animation list](https://ms-agent.fandom.com/wiki/Bonzi): useful discovery index; not authoritative for frame coverage or application usage.
- [Contemporary review](https://dis.ijs.si/mezi/pedagosko/Abonzi.pdf): original-era description and promotional illustration with globe and banana.
- [Headphones GIF](https://tenor.com/view/bonzi-bonzibuddy-headphones-coconut-listening-to-music-gif-15068845836625772363): additional visual lead, not authenticated original timing.

The parsed 3.0.7 file has **146 animation entries**, including **29 single-frame entries**. The community catalog's 148 count does not match this file. Do not silently reconcile them or present either as the number of distinct tricks. Names include entrance, continuation, return, gaze variants, and duplicated idle names. The complete extracted directory is retained rather than replacing the source with a guessed canonical list.

The earlier Smore data has 73 named entries, many placeholders. `Read` and `Write`, for example, are single-frame entries there, whereas the inspected 3.0.7 file has 31 and 37 frame entries respectively. `DoMagic1` and `DoMagic2` are single-frame entries in both inventories; their names do not establish visible magic routines.

## Reproduce the inventory

```sh
python3 Scripts/inspect-agent-animations.py /path/to/Bonzi.acs
```

The small standard-library script reads directory and animation headers according to [Remy Lebeau's observed format specification](https://uploads.s.zeid.me/ms-agent-format-spec.html). It checks directory boundaries and extracts names, frame counts, return animations, and transition types. It does not decode compressed images or play branching sequences. Original timing still requires frame-level extraction and branch-aware review.

The raw ACS and downloaded atlas remain temporary research files outside Git. No character engine, SDK, installer, or third-party API was added to the app. Reference artwork remains property of its respective rights holders and is excluded from app resources.

## Frame-level extraction

`Scripts/extract-agent-reference.py` now decodes the compressed images, composes base frames, and retains frame durations, branches, exits, and mouth-overlay metadata. Run:

```sh
python3 Scripts/extract-agent-reference.py /path/to/Bonzi.acs Validation/Original
open Validation/Original/index.html
```

The inspected file produced 2,788 base frames across 146 routines and 1,044 decoded images. Frame-level timing is retained in `timing.json`; the report is in `extraction-checks.json`. The generated atlas and full frame metadata remain ignored under Validation. Mouth overlays are parsed but not displayed in the base-frame strips. The parser uses the observed 0x20 voice flag in this file; the old prose specification labels that bit ambiguously.

Visual inspection resolved `Butternut` as a butterfly landing/flying interaction, `Juggle` as three coconuts, headphones as coconut shells with a headband/antenna, `Read` as seated book reading, `Write` as pencil and pad, and mail as a bamboo-style mailbox plus a letter. The vine entrance and landing dust are visible in `Show`. These replace the earlier name-only classification.
