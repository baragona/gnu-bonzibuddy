# Actor placement for entrance/exit choreography

Whole-character translation, rotation and positive uniform scale now sit between
articulation and pose-transition blending. Standing IK is evaluated in the actor's
local frame, so stage travel carries the complete skeleton. Existing routines
use identity placement. Hidden/shown lifecycle and actual flight routines remain
pending; no placeholder entrance action is exposed.

Joint attachment frames preserve actor scale while removing limb stretch. Prop
anchor blends also preserve scale. Stage props retain their independent frame.
The GPU validation covers all 68,673 body vertices plus worn sunglasses and
headphones, a wrist-held prop, a prop between wrist and head anchors, and a fixed
stage prop. It samples three camera angles and scales 0.001, 0.035, 0.3, 0.7, 1.
A separate 25-pair scale test interrupts movement and then interrupts it again
mid-blend, checking start continuity and convergence to a fresh target pose.

The three PNGs are diagnostic placement views, not proposed flight poses or
original-image fidelity comparisons. Quarter and left views were visually
inspected. This establishes attachment behavior, not collision avoidance,
entrance timing, vine grip fitting, dust animation, or persistent visibility.

Release build and all checks passed: 18,489 routine samples, 1,089 ordered action
transitions, 3,465 facial transition cases, and 3,751 wearable samples. Maximum
placed-transition start error was 7.45e-7; settled error was zero. Attached prop
GPU error stayed below 4e-7, and the stage prop had zero drift. Fresh neutral
front/quarter/left output is pixel-identical to the approved rest baseline.
