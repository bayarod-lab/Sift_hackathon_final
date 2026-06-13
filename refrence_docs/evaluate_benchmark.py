import json
import sys
import os
from datetime import datetime

if len(sys.argv) < 3:
    print("Usage: python3 evaluate_benchmark.py <path_to_ledger> <path_to_ground_truth>")
    sys.exit(1)

ledger_path = sys.argv[1]
gt_path = sys.argv[2]

# Load Agent Ledger
with open(ledger_path, 'r') as f:
    ledger = json.load(f)

# Load Official Ground Truth
with open(gt_path, 'r') as f:
    gt = json.load(f)

case_id = ledger.get("case_id", "UNKNOWN")
agent_verdict = ledger.get("intent_verdict", "UNKNOWN")
expected_verdict = gt.get("canonical_verdict", gt.get("intent_verdict", "UNKNOWN"))

# Standardize values for direct comparison
a_verd = agent_verdict.replace("DRAFT_", "")
e_verd = expected_verdict.replace("DRAFT_", "")

is_correct = (a_verd == e_verd)

# Handle Special Case False-Positive Gate (VIGIA-REAL-005)
fpr = 0.0
fnr_mal = 0.0
if case_id == "VIGIA-REAL-005":
    if "MALICE" in a_verd:
        fpr = 1.0  # Failed the specificity gate!
else:
    if "MALICE" in e_verd and ("BENIGN" in a_verd or "NOISE" in a_verd):
        fnr_mal = 1.0

# Extract TTP mappings if present
agent_ttps = ledger.get("mitre_ttps", [])
expected_ttps = gt.get("mitre_ttps", [])

if expected_ttps:
    matched_ttps = [ttp for ttp in agent_ttps if ttp in expected_ttps]
    ttp_coverage = len(matched_ttps) / len(expected_ttps)
else:
    ttp_coverage = 1.0 if not agent_ttps else 0.0

# Build VIGÍA Compliance Summary
score_report = {
    "agent_id": "Autonomous-DFIR-Agent-v3.1",
    "evaluation_date": datetime.utcnow().strftime("%Y-%m-%d"),
    "cases_evaluated": 1,
    "tier": "score_against",
    "results": [
        {
            "case_id": case_id,
            "agent_verdict": a_verd,
            "expected_verdict": e_verd,
            "agent_confidence": ledger.get("confidence", 0.95),
            "correct": is_correct,
            "mitre_ttps_detected": agent_ttps,
            "mitre_ttps_expected": expected_ttps
        }
    ],
    "summary": {
        "verdict_accuracy": 1.0 if is_correct else 0.0,
        "fpr": fpr,
        "fnr_mal": fnr_mal,
        "ttp_coverage": round(ttp_coverage, 2)
    }
}

# Output to terminal and save artifact
output_path = os.path.dirname(ledger_path) + "/benchmark_report.json"
with open(output_path, 'w') as out_f:
    json.dump(score_report, out_f, indent=2)

print("\n========================================================")
print("     📊 VIGÍA BENCHMARK METRIC ENGINE COMPLETED 📊")
print("========================================================")
print(json.dumps(score_report, indent=2))
print(f"\n[+] Performance evaluation matrix saved to: {output_path}")

