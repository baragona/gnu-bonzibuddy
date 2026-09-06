# Shared resting-hand contact correction — September 5, 2026

The shared rest pose now holds the fingers ahead of the torso and separates the hands in height and depth. Finger directions and curl retain a compact pose near the chest. `FanRestPose` centralizes the calibration used by idle, IK entrance/return blending, and wrist orientation. The fan mesh, facial controls, materials, lighting, and foot planting are unchanged.

Resting finger curl and authored active finger curl are blended separately. This preserves existing active prop grips rather than changing their shape as a side effect of the rest correction. The distinction matters for partially open grips such as sunglasses and banana handling. Surface-contact headphone grips retain their own articulation.

The full-catalog comparison covers 28 actions at 120 Hz in normal and both-wearables configurations. It compares against the original geometry audit, using the newer headphone-contact checkpoint for Headphones. Raw samples remain in `Validation/RestCatalogAudit*`; `comparison.json`, both summary files, and `crossing-changes.csv` preserve coverage, per-pair changes, and residual problems.

Zero detected crossings in idle is a sampled geometry result, not proof of all contact conditions. The detector excludes coplanar overlap, containment without surface crossing, same-hand finger self-collision, connected boundary regions, floor, and the separate teeth mesh. Arbitrary interrupted timelines are not exhaustively collision-audited. Triangle-pair counts and spans are not penetration depth or visual severity.

The four diagnostic camera views show hand axes and palm normals; `rest-angles.png` preserves the unannotated front/quarter/left view. The approved appearance reference remains intact. The rest arms and their shadows intentionally differ, so the prior whole-image neutral-preservation comparison is no longer the appropriate invariant. `head-preservation.json` reports a fixed head-region comparison against that reference.

`original-before.json` and `original-after.json` compare the old and revised neutral renders with original ACS HeadphonesContinued frame 0 at identical native resolution and comparison settings. Both fail the unchanged near-identity gate. Original performance fidelity remains incomplete, and a better rest pose does not resolve the remaining prop-transfer defects.

Reproduce the scans from the repository root after building:

```sh
Build/BonziBuddy.app/Contents/MacOS/BonziBuddy --audit-animation-geometry --audit-fps 120 --audit-output Validation/RestCatalogAudit
Build/BonziBuddy.app/Contents/MacOS/BonziBuddy --audit-animation-geometry --audit-fps 120 --with-wearables --audit-output Validation/RestCatalogAudit-wearables
Build/BonziBuddy.app/Contents/MacOS/BonziBuddy --audit-animation-geometry --action Idle --audit-render-time 1.4 --audit-output Validation/RestContacts
```

Final coverage is 42,082 poses: 21,041 in each configuration. Idle, Look Left, Look Right, and Speak have zero detected crossings in their sampled cycles. Frames with any crossing fall from 19,592 to 12,983 normally and from 19,598 to 12,983 with both wearables. No new colliding region/prop pairs appear; this does not mean every existing pair improves. For example, right-hand/letter crossings persist for about 22–24 additional samples in Mail Read/Next, despite lower peak triangle-pair counts. Those transfer paths remain work.

Two free-hand adjustments were verified after the complete shared-rest scan: sunglasses pickup/removal lowers the free hand beside the body, consistent with the original, and the banana bite rests it lower on the abdomen. Both final full-clip scans have zero detected right-hand crossings, and headphone accessory clearance remains intact. `incremental-verification.json` records the two revalidated actions; the final aggregate replaces their earlier samples.

Validation passed: routine contracts, 784 ordered skeletal action pairs, 2,520 facial transition cases, clap/chest-beat proximity checks, headset attachments, and wearable scheduling/combinations. Idle's 70-frame preview covers 210 views without viewport clipping. The head-region premultiplied RGBA MAE is 3.67e-5; its maximum edge-channel difference is 0.502, so it is not an exact pixel match.

At matched native resolution, the original-reference silhouette IoU changes from 0.8210 to 0.8223, while foreground RGB MAE changes from 0.2046 to 0.2214. Both versions fail the unchanged 0.95 / 0.05 gate. Physical clearance is improved; original likeness and complete visual feature parity remain unfinished.

Final sunglasses and banana previews cover 219 and 109 frames respectively, each from three angles with no viewport clipping. Their selected original comparisons and frame-selection metadata are preserved alongside the rest comparison; both also fail the original-likeness gate.
