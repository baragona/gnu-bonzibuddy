#!/usr/bin/env python3
"""Offline bounded coordinate search using the real Metal geometry audit.

The score is a diagnostic crossing count, not a contact-depth or visual-quality
metric. Every selected pose still needs multi-angle review and a full clip scan.
"""
import argparse
import copy
import json
import math
from pathlib import Path
import subprocess

# Reject malformed studies before launching Metal or creating output files.
def finite(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)


def validate_spec(spec, passes):
    vectors = {"palmContact", "shoulderOffset", "elbowBend", "fingers", "palm"}
    scalars = {"grip", "thumbFold"}
    if not isinstance(spec, dict) or set(spec) - {"action", "time", "times", "pose", "variables"}:
        raise ValueError("Unknown study field or non-object specification")
    if passes < 1:
        raise ValueError("passes must be positive")
    if not isinstance(spec.get("action"), str) or not spec["action"].strip():
        raise ValueError("action must be a nonempty string")
    if ("time" in spec) == ("times" in spec):
        raise ValueError("Supply exactly one of time or times")
    times = spec.get("times", [spec.get("time")])
    if not isinstance(times, list) or not times or not all(finite(t) and t >= 0 for t in times):
        raise ValueError("times must contain finite nonnegative samples")
    pose = spec.get("pose")
    if not isinstance(pose, dict) or set(pose) - {"left", "right"}:
        raise ValueError("pose must contain only left/right hand objects")
    for hand in pose.values():
        if not isinstance(hand, dict) or set(hand) - vectors - scalars:
            raise ValueError("Unknown hand field")
        for field, value in hand.items():
            if field in vectors:
                if not isinstance(value, list) or len(value) != 3 or not all(finite(v) for v in value):
                    raise ValueError("Hand vectors must contain three finite numbers")
            elif not finite(value) or not 0 <= value <= 1:
                raise ValueError("Hand scalar must be in [0,1]")
        if ("fingers" in hand) != ("palm" in hand):
            raise ValueError("Supply fingers and palm together")
    variables = spec.get("variables")
    if not isinstance(variables, list):
        raise ValueError("variables must be a list")
    for variable in variables:
        if not isinstance(variable, list) or len(variable) != 6:
            raise ValueError("Each variable needs side, field, axis, low, high, step")
        side, field, axis, low, high, step = variable
        if not isinstance(side, str) or not isinstance(field, str) or side not in pose or field not in vectors or field not in pose[side]:
            raise ValueError("Variable must reference an existing hand vector")
        if type(axis) is not int or axis not in (0, 1, 2):
            raise ValueError("Variable axis must be 0, 1, or 2")
        if not all(finite(v) for v in (low, high, step)) or low > high or step <= 0:
            raise ValueError("Variable bounds must be ordered and step positive")
        if not low <= pose[side][field][axis] <= high:
            raise ValueError("Initial coordinate is outside variable bounds")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("spec", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--passes", type=int, default=2)
    args = parser.parse_args()
    try:
        spec = json.loads(args.spec.read_text())
        validate_spec(spec, args.passes)
    except (OSError, ValueError) as error:
        parser.error(str(error))
    args.output = args.output.resolve()
    args.output.mkdir(parents=True, exist_ok=True)
    binary = Path(__file__).resolve().parents[1] / "Build/BonziBuddy.app/Contents/MacOS/BonziBuddy"
    pose = spec["pose"]
    trials = []

    def evaluate(candidate):
        patch = args.output / "candidate.json"
        patch.write_text(json.dumps(candidate, indent=2) + "\n")
        reports = []
        for time in spec.get("times", [spec.get("time", 0)]):
            subprocess.run([str(binary), "--audit-animation-geometry", "--action", spec["action"],
                            "--audit-sample-time", str(time), "--audit-hand-patch", str(patch),
                            "--audit-output", str(args.output / "audit")], check=True, stdout=subprocess.DEVNULL, cwd=Path(__file__).resolve().parents[1])
            reports.append(json.loads((args.output / "audit" / (spec["action"].lower().replace(" ", "-") + ".json")).read_text()))
        report = reports[0] if len(reports) == 1 else {"samples": reports}
        peaks = [peak for sample in reports for peak in sample["summary"]["peaks"]]
        score = sum(row["trianglePairs"] for row in peaks)
        trials.append({"trial": len(trials), "score": score, "pose": candidate, "crossings": peaks})
        (args.output / "trials.json").write_text(json.dumps(trials, indent=2) + "\n")
        return score, report

    best, report = evaluate(pose)
    # Preserve the initial result even when the first candidate fails.
    (args.output / "best.json").write_text(json.dumps(pose, indent=2) + "\n")
    (args.output / "best-audit.json").write_text(json.dumps(report, indent=2) + "\n")
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


if __name__ == "__main__":
    main()
