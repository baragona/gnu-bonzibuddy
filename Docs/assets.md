# Assets and provenance

`Resources/FanModel/` is the canonical runtime asset directory:

- `FanRigged.mesh`: subdivided body, eyes, and mouth with eight skinning influences.
- `FanRig.json`: joint hierarchy and coordinate normalization.
- `FanMorphs.bin`, `FanMorphs.json`: fifteen facial target deltas and metadata.
- `FanTeeth.mesh`: separately skinned teeth.
- `ATTRIBUTION.txt`: creator, listing, source link, and modifications; bundled with the app.

The imported fan model is credited to YinyangGio. The recorded public listing declares Creative Commons Attribution; source details are retained in the attribution and [conversion research history](../References/CandidateModel/README.md). Original sprite references and their provenance are in [References](../References/README.md). They are not bundled with the app.

## Regeneration

A normal build uses the committed runtime assets. It does not need a model editor, downloaded SDK, or raw Cinema 4D library. `References/CandidateModel/scene.json` is the portable source interchange used by the Python conversion tools. These tools use Python's standard library.

Run from the repository root:

```sh
python3 Scripts/check-fan-export.py
python3 Scripts/convert-fan-preview.py --output Resources/FanModel
python3 Scripts/convert-fan-preview.py --parts teeth --output References/CandidateModel/Teeth
cp References/CandidateModel/Teeth/FanRigged.mesh Resources/FanModel/FanTeeth.mesh
python3 Scripts/build-fan-morphs.py
python3 Scripts/check-fan-mesh.py
```

The converter also writes an ignored static preview. Morph endpoint meshes stay under the ignored `References/CandidateModel/MorphVariants/` directory and are needed for the endpoint comparisons in `--preview-fan`. Regeneration can change tracked assets; review the diff and render results before committing.

The raw source library, extracted C4D blocks, generated previews, and morph variants remain local and ignored. `blocks.json` preserves source hashes and extraction offsets. The optional Cineware reader sources are retained in `Scripts/`; rebuilding that reader requires the external SDK described in the historical notes. Neither that SDK nor its binary is part of this repository or app.

The legacy `Resources/Bonzi.mesh` and `Bonzi.obj` are ignored generated outputs. The normal build regenerates them from `Character.swift`, `Mesh.swift`, and `Animation.swift` as needed.
