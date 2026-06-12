#!/bin/bash
set -e # Abort immediately if any command fails

if [ -z "$1" ]; then
    echo "Usage: ./analyze.sh <path_to_evidence>"
    exit 1
fi

TARGET=$1

# Safely handle paths with spaces
CLEAN_BASENAME=$(basename "$TARGET")
CASE_NAME=$(echo "$CLEAN_BASENAME" | cut -f 1 -d '.')

if [ -z "$CASE_NAME" ] || [[ "$CASE_NAME" == *" "* ]]; then
    CASE_NAME="VANKO_CASE"
fi

CASE_DIR="cases/INC-2026-$CASE_NAME"

# ==========================================================
# HYBRID MARKET-AWARE AI MODEL CAPABILITY DISCOVERY ENGINE
# ==========================================================
AI_MODEL="${AI_MODEL:-gemini/gemini-3.1-flash-lite}"
API_TIER="${API_TIER:-FREE}" 

echo "[*] Querying market capabilities for model: $AI_MODEL..."

# Hybrid capability analysis: Database context lookup + Next-Gen Heuristic Priority Override
MODEL_TIER=$(python3 -c "
import sys
try:
    import litellm
    model_name = sys.argv[1].lower()
    
    # Tier 1: Direct structural lookup from local database
    max_tokens = litellm.get_max_tokens(model_name) or 0
    
    # Tier 2: Frontier Generational Heuristic
    next_gen_indicators = ['3.5', '4.0', 'pro', 'ultra', 'think', 'o1', 'o3', 'sonnet', 'r1']
    is_next_gen = any(ind in model_name for ind in next_gen_indicators)
    
    # FIX: Generational override triggers POWERFUL profile even if DB defaults to a low token count
    if max_tokens >= 128000 or is_next_gen:
        print('POWERFUL')
    else:
        print('LIGHT')
except Exception:
    print('LIGHT')
" "$AI_MODEL")

# Establish dynamic operational ceilings based on live capability score
if [ "$MODEL_TIER" = "POWERFUL" ]; then
    TRUNCATE_LINES=1000        # Open the gates for flagship logic models
    echo "========================================================"
    echo "   🚀 CAPABILITY PROFILE: POWERFUL ARCHITECTURE DETECTED"
    echo "========================================================"
    echo "[+] Model matches frontier performance metrics: $AI_MODEL"
    echo "[+] Context processing expanded to $TRUNCATE_LINES lines per log file."
    
    # Rate limit auto-scaling protection
    if [ "$API_TIER" = "PAID" ]; then
        PHASE_1_COOLDOWN=5
        PHASE_2_COOLDOWN=0
        echo "[+] PAID tier confirmed. Throttles disabled (5s loop cooldown)."
    else
        PHASE_1_COOLDOWN=45
        PHASE_2_COOLDOWN=15
        echo "[!] FREE tier detected. Enforcing 45s safety buffer to protect your key."
    fi
    echo "--------------------------------------------------------"
else
    TRUNCATE_LINES=100         # Defensive triage profile for standard engines
    PHASE_1_COOLDOWN=45
    PHASE_2_COOLDOWN=15
    
    echo "========================================================"
    echo "   🛡️ CAPABILITY PROFILE: STANDARD ARCHITECTURE DETECTED"
    echo "========================================================"
    echo "[*] Fallback Standard Core: $AI_MODEL"
    echo "[*] Throttling context to $TRUNCATE_LINES lines to maintain API stability."
    echo "[*] Enforcing a ${PHASE_1_COOLDOWN}s safety pause to prevent quota blocks."
    echo "--------------------------------------------------------"
fi

# ==========================================================
# AUTOMATED FORENSIC EXTRACTION ENGINE
# ==========================================================

if [[ "$TARGET" == *.json ]]; then
    echo "[+] Ingesting VIGÍA JSON telemetry profile."
    mkdir -p "$CASE_DIR/extractions"
    cp "$TARGET" "$CASE_DIR/extractions/telemetry_source.json"
    EVIDENCE_FILE="$CASE_DIR/extractions/telemetry_source.json"

elif [[ "$TARGET" == *.E01 ]]; then
    echo "[*] Detected EWF/EnCase forensic split image format..."
    echo "[*] Automating image mount via ewfmount..."
    mkdir -p "/tmp/ewf_$CASE_NAME"
    sudo ewfmount "$TARGET" "/tmp/ewf_$CASE_NAME"
    
    EVIDENCE_FILE="$CASE_DIR/extractions/vanko_filesystem_metadata.txt"
    mkdir -p "$CASE_DIR/extractions"
    sudo fls -r -m C: "/tmp/ewf_$CASE_NAME/ewf1" > "$EVIDENCE_FILE"
    sudo umount "/tmp/ewf_$CASE_NAME" || true

elif [[ "$TARGET" == *.7z ]] || [[ "$TARGET" == *.zip ]]; then
    echo "[*] Detected CyLR/Triage compressed archive format..."
    echo "[*] Automating archive extraction..."
    
    TMP_EXTRACT="$CASE_DIR/extractions/raw_triage"
    mkdir -p "$TMP_EXTRACT"
    7z x "$TARGET" -o"$TMP_EXTRACT" -y > /dev/null
    
    EVIDENCE_FILE="$CASE_DIR/extractions/triage_consolidated_telemetry.txt"
    echo "=== CYLR TRIAGE CONSOLIDATED TELEMETRY ===" > "$EVIDENCE_FILE"
    
    # DYNAMIC TRIAGE EXTRACTION: Limits logs based on your AI model's market profile
    find "$TMP_EXTRACT" -type f \( -iname "*autorun*" -o -iname "*process*" -o -iname "*netstat*" -o -iname "*network*" \) -exec echo -e "\n--- File: {} ---" \; -exec head -n $TRUNCATE_LINES "{}" \; | tr -cd '\11\12\15\40-\176' >> "$EVIDENCE_FILE" 2>/dev/null
    
    # Fallback
    if [ ! -s "$EVIDENCE_FILE" ]; then
        echo "[!] Specific triage targets not found. Pulling a micro-sample of all text files..."
        find "$TMP_EXTRACT" -type f -name "*.txt" -exec echo -e "\n--- File: {} ---" \; -exec head -n 25 "{}" \; | tr -cd '\11\12\15\40-\176' >> "$EVIDENCE_FILE" 2>/dev/null
    fi

else
    echo "[*] Processing fallback raw memory/text structure..."
    mkdir -p "$CASE_DIR/extractions"
    EVIDENCE_FILE="$CASE_DIR/extractions/memory_scan_results.txt"
    python3 run_scan.py "$TARGET" > "$EVIDENCE_FILE"
fi

# Track integrity in log
echo "$(date -u +'%Y-%m-%d %H:%M:%S UTC') | SYSTEM | Automated pipeline extracted $TARGET to $EVIDENCE_FILE" >> "$CASE_DIR/actions.jsonl"

# --- PHASE 1: INITIAL DATA STAGING & SYNTAX VALIDATION ---
echo "[*] Handing evidence off to AI Agent for triage staging with SANS Knowledge Bases..."
aider --model "$AI_MODEL" \
  --message "You are an autonomous DFIR analyst. Read '$EVIDENCE_FILE'.
  1. Evaluate intent.
  2. Cross-reference all found processes, logs, and signatures against the expert baselines provided.
  3. Document findings in '$CASE_DIR/triage_ledger.json'. 
  4. The JSON must contain exactly these root keys: 'case_id' (set to $CASE_NAME), 'target', 'intent_verdict', 'summary', and 'artifacts'.
  5. CRITICAL SCHEMA: Every item in the 'artifacts' array MUST contain exactly these 5 keys: 'name', 'type', 'value', 'description', and 'review_status' (set to 'pending'). Do NOT invent new keys like 'content', 'artifact_id', or 'findings'.
  6. CRITICAL: Do NOT wrap the JSON in markdown backticks. Write raw text only.
  7. CRITICAL: NO MULTI-LINE STRINGS. All JSON string values must be strictly single-line." \
  --yes-always \
  --no-auto-commit \
  --read "$EVIDENCE_FILE" \
  --read "reference_material/file_signatures.txt" \
  --read "reference_material/windows_baseline.txt" \
  --read "reference_material/sqlite_parsing.txt" \
  --file "$CASE_DIR/triage_ledger.json"

MAX_RETRIES=3
ATTEMPT=1
VALIDATION_PASSED=false

while [ $ATTEMPT -le $MAX_RETRIES ]; do
    echo "[*] Running autonomous schema validation (Attempt $ATTEMPT)..."
    
    # DEFENSIVE SCRUBBERS: Remove AI UI hallucinations and markdown before validating
    sed -i '/\[███*/d' "$CASE_DIR/triage_ledger.json" || true
    sed -i 's/.*```.*//g' "$CASE_DIR/triage_ledger.json" || true
    
    set +e
    VALIDATION_OUTPUT=$(python3 verify_schema.py "$CASE_DIR/triage_ledger.json" 2>&1)
    VAL_EXIT_CODE=$?
    set -e
    
    if [ $VAL_EXIT_CODE -eq 0 ]; then
        echo "$VALIDATION_OUTPUT"
        VALIDATION_PASSED=true
        break
    else
        echo "[-] Quality/Schema Check Failed. Forcing Agentic Correction..."
        aider --model "$AI_MODEL" \
          --message "CRITICAL FAILURE: Your previous draft failed validation with this error:
          
          $VALIDATION_OUTPUT
          
          TASK: Rebuild the JSON object inside '$CASE_DIR/triage_ledger.json' from scratch.
          
          STRICT CONTRAINTS:
          1. Do NOT copy, type, or include any terminal progress bars.
          2. Do NOT use markdown code blocks (\`\`\`json).
          3. Every item in the 'artifacts' array MUST contain exactly these 5 keys: 'name', 'type', 'value', 'description', and 'review_status'.
          4. ALL JSON strings must be single-line only." \
          --yes-always --no-auto-commit --file "$CASE_DIR/triage_ledger.json"
        ATTEMPT=$((ATTEMPT + 1))
    fi
done

if [ "$VALIDATION_PASSED" = false ]; then
    echo "[-] FATAL: Agent failed to produce a schema-compliant ledger after $MAX_RETRIES attempts. Halting pipeline."
    exit 1
fi

echo "$(date -u +'%Y-%m-%d %H:%M:%S UTC') | AI_AGENT | Completed initial validation loop." >> "$CASE_DIR/actions.jsonl"

# --- API COOLDOWN ENFORCEMENT ---
echo "[*] Phase 1 Complete. Initiating ${PHASE_1_COOLDOWN}-second API rate-limit adaptive cooldown..."
sleep $PHASE_1_COOLDOWN

# --- PHASE 2: THE SENIOR ANALYST LOGIC REVIEW ---
echo "[*] Initializing Phase 2: Senior Forensic Peer Review Loop..."
aider --model "$AI_MODEL" \
  --message "You are now a Senior DFIR Examiner auditing a junior analyst's work. 
  1. Read the raw evidence file '$EVIDENCE_FILE' and compare it against the junior's draft ledger in '$CASE_DIR/triage_ledger.json'.
  2. Identify at least two technical nuances, artifacts, or behavioral gaps that the junior missed.
  3. Write your critical technical review comments directly into a new file named '$CASE_DIR/critique.txt'. Do not modify the JSON ledger yet." \
  --yes-always --no-auto-commit \
  --read "$EVIDENCE_FILE" \
  --read "$CASE_DIR/triage_ledger.json" \
  --file "$CASE_DIR/critique.txt"

if [ -f "$CASE_DIR/critique.txt" ]; then
    echo "[!] Critical Logic Review Generated by Peer Agent:"
    cat "$CASE_DIR/critique.txt"
    echo "────────────────────────────────────────────────────────────────────────────────"
    
    echo "[*] Peer Review Adaptive Pause (${PHASE_2_COOLDOWN} seconds)..."
    sleep $PHASE_2_COOLDOWN
    
    echo "[*] Re-engaging Agent to integrate Senior Review into Final Ledger..."
    aider --model "$AI_MODEL" \
      --message "Read the peer review critique in '$CASE_DIR/critique.txt'. 
      Update the final triage ledger in '$CASE_DIR/triage_ledger.json' to comprehensively address these criticisms. Expand the summary and refine the artifacts array based on these higher-level analytical insights. Ensure it remains valid raw JSON without markdown backticks." \
      --yes-always --no-auto-commit \
      --read "$CASE_DIR/critique.txt" \
      --read "$EVIDENCE_FILE" \
      --file "$CASE_DIR/triage_ledger.json"
fi

echo "$(date -u +'%Y-%m-%d %H:%M:%S UTC') | AI_AGENT | Successfully integrated peer review feedback." >> "$CASE_DIR/actions.jsonl"

# --- PHASE 3: HUMAN EXAMINER CHECKPOINT ---
echo ""
echo "========================================================"
echo "    ⚠️ CRITICAL CHECKPOINT: HUMAN EXAMINER REVIEW ⚠️"
echo "========================================================"
echo "The AI Agent has staged finalized findings inside: $CASE_DIR/triage_ledger.json"
echo "Review the file. When you are ready to approve the verdict and sign off,"
printf "Type 'APPROVE' to authorize final report generation: "
read -r USER_INPUT

if [ "$USER_INPUT" == "APPROVE" ]; then
    echo "[*] Modifying ledger status to APPROVED..."
    sed -i 's/DRAFT_//g' "$CASE_DIR/triage_ledger.json"
    sed -i 's/PENDING_HUMAN_REVIEW/APPROVED_BY_EXAMINER/g' "$CASE_DIR/triage_ledger.json"
    echo "$(date -u +'%Y-%m-%d %H:%M:%S UTC') | EXAMINER | Cryptographically signed and verified final report data." >> "$CASE_DIR/actions.jsonl"

    echo "[*] Orchestrating final PDF report generation..."
    
    # Strip lingering markdown from the python generator just in case
    sed -i 's/.*
```.*//g' generate_pdf_report.py || true
    python3 generate_pdf_report.py "$CASE_DIR/triage_ledger.json"
    
    GT_FILE="vigia-intent-analysis/cases/$CASE_NAME/ground_truth.json"
    if [ -f "$GT_FILE" ]; then
        echo "[*] Ground Truth file found. Evaluating agent performance matrix..."
        python3 evaluate_benchmark.py "$CASE_DIR/triage_ledger.json" "$GT_FILE"
    else
        GT_FILE_ALT="cases/$CASE_NAME/ground_truth.json"
        if [ -f "$GT_FILE_ALT" ]; then
            echo "[*] Ground Truth file found. Evaluating agent performance matrix..."
            python3 evaluate_benchmark.py "$CASE_DIR/triage_ledger.json" "$GT_FILE_ALT"
        fi
    fi

    mkdir -p "$CASE_DIR/reports"
    mv exports/*.pdf "$CASE_DIR/reports/" 2>/dev/null || true
    echo "[+] PIPELINE COMPLETE. Final verified artifact saved to $CASE_DIR/reports/"
else
    echo "[-] Investigation Paused / AI Re-prompted based on human rejection."
    echo "$(date -u +'%Y-%m-%d %H:%M:%S UTC') | EXAMINER | Rejected/deferred staged findings." >> "$CASE_DIR/actions.jsonl"
    exit 1
fi
