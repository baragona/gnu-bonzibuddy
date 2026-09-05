# Prop source geometry

`ne_110m_land.geojson` is the public-domain Natural Earth land map used to bake the globe mask. See `Resources/Props/ATTRIBUTION.txt` for source and terms. Regenerate without network access:

```sh
swift -module-cache-path .build/clang-cache Scripts/bake-globe-texture.swift References/Props/ne_110m_land.geojson Resources/Props/globe-land.png
```
