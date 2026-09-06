#!/usr/bin/env python3
"""Offline bounded coordinate search using the real Metal geometry audit.

The score is a diagnostic crossing count, not a contact-depth or visual-quality
metric. Every selected pose still needs multi-angle review and a full clip scan.
"""
import argparse
import copy
import json
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("spec", type=Path)
parser.add_argument("output", type=Path)
parser.add_argument("--passes", type=int, default=2)
args = parser.parse_args()
spec = json.loads(args.spec.read_text())
args.output.mkdir(parents=True, exist_ok=True)
binary = Path("Build/BonziBuddy.app/Contents/MacOS/BonziBuddy").resolve()
pose = spec["pose"]
trials = []


def evaluate(candidate):
    patch = args.output / "candidate.json"
    patch.write_text(json.dumps(candidate, indent=2) + "\n")
    reports = []
    for time in spec.get("times", [spec.get("time", 0)]):
        subprocess.run([str(binary), "--audit-animation-geometry", "--action", spec["action"],
                        "--audit-sample-time", str(time), "--audit-hand-patch", str(patch),
                        "--audit-output", str(args.output / "audit")], check=True, stdout=subprocess.DEVNULL)
        reports.append(json.loads((args.output / "audit" / (spec["action"].lower().replace(" ", "-") + ".json")).read_text()))
    report = reports[0] if len(reports) == 1 else {"samples": reports}
    peaks = [peak for sample in reports for peak in sample["summary"]["peaks"]]
    score = sum(row["trianglePairs"] for row in peaks)
    trials.append({"trial": len(trials), "score": score, "pose": candidate, "crossings": peaks})
    return score, report


best, report = evaluate(pose)
initial = best
for iteration in range(args.passes):
    for variable in spec["variables"]:
        side, field, axis, low, high, step = variable
        for sign in [-1, 1]:
            candidate = copy.deepcopy(pose)
            value = min(high, max(low, candidate[side][field][axis] + sign * step / (iteration + 1)))
            if value == candidate[side][field][axis]:
                continue
            candidate[side][field][axis] = value
            score, current = evaluate(candidate)
            if score < best:
                best, pose, report = score, candidate, current
                (args.output / "best.json").write_text(json.dumps(pose, indent=2) + "\n")
                (args.output / "best-audit.json").write_text(json.dumps(report, indent=2) + "\n")
            if len(trials) % 10 == 0:
                print(f"{len(trials)} candidates: initial {initial}, best {best} triangle crossings", flush=True)
(args.output / "trials.json").write_text(json.dumps(trials, indent=2) + "\n")
(args.output / "best.json").write_text(json.dumps(pose, indent=2) + "\n")
(args.output / "best-audit.json").write_text(json.dumps(report, indent=2) + "\n")
print(f"Completed {len(trials)} candidates: {initial} -> {best}; visual review and full-clip audit still required.")
