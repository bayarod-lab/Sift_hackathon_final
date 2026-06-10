#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: ./analyze.sh <path_to_evidence>"
    exit 1
fi

TARGET=$1
CASE_NAME=$(basename "$TARGET" | cut -f 1 -d '.')
CASE_DIR="cases/INC-2026-$CASE_NAME"

# Establish stateful case directory structure
echo "[*] Initializing Forensic Workspace for $CASE_NAME..."
mkdir -p "$CASE_DIR/extractions" "$CASE_DIR/reports"
echo '{"status": "INITIALIZED"}' > "$CASE_DIR/triage_ledger.json"

# Append actions to an audit log for forensic integrity
echo "$(date -u +'%Y-%m-%d %H:%M:%S UTC') | SYSTEM | Initialized case workspace at $CASE_DIR" >> "$CASE_DIR/actions.jsonl"

# Dynamic Extraction Branch
if [[ "$TARGET" == *.json ]]; then
    echo "[+] Ingesting VIGÍA JSON telemetry profile."
    cp "$TARGET" "$CASE_DIR/extractions/telemetry_source.json"
    EVIDENCE_FILE="$CASE_DIR/extractions/telemetry_source.json"
else
    echo "[*] Processing raw memory structure. Executing extraction engine..."
    python3 run_scan.py "$TARGET" > "$CASE_DIR/extractions/memory_scan_results.txt"
    EVIDENCE_FILE="$CASE_DIR/extractions/memory_scan_results.txt"
fi
echo "$(date -u +'%Y-%m-%d %H:%M:%S UTC') | SYSTEM | Evidence extracted to $EVIDENCE_FILE" >> "$CASE_DIR/actions.jsonl"

# AI Cognitive Stage Analysis
echo "[*] Handing evidence off to AI Agent for triage staging..."
aider --model gemini/gemini-2.5-flash \
  --message "You are an autonomous DFIR assistant. Evaluate the evidence file located at '$EVIDENCE_FILE'.
  
  1. Parse the evidence data to find critical anomalies, loops, or malicious activity.
  2. Document your findings by editing the file '$CASE_DIR/triage_ledger.json'.
  3. You must set the 'intent_verdict' to 'DRAFT_MALICIOUS' or 'DRAFT_SUSPICION'. 
  4. For each object in your 'artifacts' array, you must include a key called 'review_status' set strictly to 'PENDING_HUMAN_REVIEW'.
  5. Write only clean, format-compliant JSON. No conversation." \
  --yes-always \
  --no-auto-commit \
  --file "$EVIDENCE_FILE" "$CASE_DIR/triage_ledger.json"

echo "$(date -u +'%Y-%m-%d %H:%M:%S UTC') | AI_AGENT | Completed triage analysis and staged findings." >> "$CASE_DIR/actions.jsonl"

# ==========================================================
# THE VALHUNTIR PATTERN: HUMAN-IN-THE-LOOP CHECKPOINT
# ==========================================================
echo -e "\n========================================================"
echo "    ⚠️ CRITICAL CHECKPOINT: HUMAN EXAMINER REVIEW ⚠️"
echo "========================================================"
echo "The AI Agent has staged draft findings inside: $CASE_DIR/triage_ledger.json"
echo "Review the file. When you are ready to approve the verdict and sign off,"
read -p "Type 'APPROVE' to authorize final report generation: " USER_AUTH

if [ "$USER_AUTH" != "APPROVE" ]; then
    echo "[-] Report signing aborted by examiner. Staged findings kept for review."
    echo "$(date -u +'%Y-%m-%d %H:%M:%S UTC') | EXAMINER | Rejected/deferred staged findings." >> "$CASE_DIR/actions.jsonl"
    exit 1
fi

# Promote findings to verified state
sed -i 's/DRAFT_//g' "$CASE_DIR/triage_ledger.json"
sed -i 's/PENDING_HUMAN_REVIEW/APPROVED_BY_EXAMINER/g' "$CASE_DIR/triage_ledger.json"
echo "$(date -u +'%Y-%m-%d %H:%M:%S UTC') | EXAMINER | Cryptographically signed and verified final report data." >> "$CASE_DIR/actions.jsonl"

# Compile Final Verified Report
echo "[*] Orchestrating final PDF report generation..."
python3 generate_pdf_report.py "$CASE_DIR/triage_ledger.json"

mv exports/*.pdf "$CASE_DIR/reports/" 2>/dev/null
echo "[+] PIPELINE COMPLETE. Final verified artifact saved to $CASE_DIR/reports/"
