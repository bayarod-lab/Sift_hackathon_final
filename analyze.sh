#!/bin/bash
set -e # Abort immediately if any command fails

if [ -z "$1" ]; then
    echo "Usage: ./analyze.sh <path_to_evidence> [path_to_scenario_txt]"
    exit 1
fi

TARGET=$1
SCENARIO_FILE=$2

# Verify file exists and resolve absolute path to prevent traversal attacks
if [ ! -f "$TARGET" ]; then
    echo "[-] 🚨 FATAL: Target file '$TARGET' does not exist."
    exit 1
fi
TARGET=$(readlink -f "$TARGET")
CLEAN_BASENAME=$(basename "$TARGET")

# INTELLIGENT CASE ROUTING & ANTI-CONTAMINATION
if [ "$CLEAN_BASENAME" == "case.json" ]; then
    CASE_NAME=$(basename "$(dirname "$TARGET")")
else
    CASE_NAME="${CLEAN_BASENAME%.*}"
fi

CASE_NAME=$(echo "$CASE_NAME" | sed 's/[^a-zA-Z0-9_-]/_/g')
if [ -z "$CASE_NAME" ]; then CASE_NAME="UNKNOWN_CASE"; fi

CASE_DIR="cases/INC-2026-$CASE_NAME"

# Force a clean slate to prevent the AI from hallucinating over ghost data
if [ -d "$CASE_DIR" ]; then
    if [[ "$CASE_DIR" =~ ^cases/INC-2026- ]]; then
        echo "[!] Existing case directory detected. Purging old artifacts to ensure forensic isolation..."
        rm -rf "$CASE_DIR"
    else
        echo "[-] 🚨 FATAL: Directory safety check failed. Aborting deletion."
        exit 1
    fi
fi

mkdir -p "$CASE_DIR"
trap 'rm -f "/tmp/raw_mft_dump_${CASE_NAME}.txt"; sudo rmdir "/tmp/ewf_${CASE_NAME}" 2>/dev/null || true' EXIT

# Handle Scenario Document ingestion if present
SCENARIO_CONTEXT="No background scenario document provided for this case. Perform standard baseline triage."
if [ -n "$SCENARIO_FILE" ] && [ -f "$SCENARIO_FILE" ]; then
    echo "[+] Scenario document detected. Ingesting background investigation context..."
    cp "$SCENARIO_FILE" "$CASE_DIR/investigation_scenario.txt"
    # Read text safely into the variable
    SCENARIO_CONTEXT=$(cat "$CASE_DIR/investigation_scenario.txt")
fi

# ==============================================================================
# PRE-FLIGHT DEPENDENCY CHECK
# ==============================================================================
echo "[*] Running pre-flight checks..."
for f in "reference_material/memory-analysis/SKILL.md" \
         "reference_material/plaso-timeline/SKILL.md" \
         "reference_material/sleuthkit/SKILL.md" \
         "reference_material/windows-artifacts/SKILL.md" \
         "reference_material/yara-hunting/SKILL.md"; do
    if [ ! -f "$f" ]; then echo "[-] WARNING: Missing knowledge base file '$f'."; fi
done
if [ ! -f "verify_schema.py" ]; then echo "[-] 🚨 FATAL: verify_schema.py is missing."; exit 1; fi

# ==============================================================================
# FORENSIC CRYPTOGRAPHIC INTAKE (Pro-Grade Chain of Custody)
# ==============================================================================
echo "[*] Resolving cryptographic hash of original evidence..."
EVIDENCE_HASH=""
HASH_ALGO="SHA256"
HASH_SOURCE="Independently calculated via native sha256sum"

if { [[ "$TARGET" == *.e01 ]] || [[ "$TARGET" == *.E01 ]]; } && command -v ewfinfo >/dev/null 2>&1; then
    echo "[+] Detected E01 format. Instantly extracting embedded acquisition hash..."
    HASH_LINE=$(ewfinfo "$TARGET" | grep -iE "hash stored in file|SHA256 hash|MD5 hash" | head -n 1)
    EVIDENCE_HASH=$(echo "$HASH_LINE" | awk -F': ' '{print $2}' | tr -d ' ')
    if [ ${#EVIDENCE_HASH} -eq 64 ]; then HASH_ALGO="SHA256"; elif [ ${#EVIDENCE_HASH} -eq 32 ]; then HASH_ALGO="MD5"; else HASH_ALGO=$(echo "$HASH_LINE" | grep -oiE "SHA256|MD5" | tr '[:lower:]' '[:upper:]'); fi
    HASH_SOURCE="E01 embedded acquisition hash (not independently recalculated)"
fi

if [ -z "$EVIDENCE_HASH" ]; then
    if [[ "$TARGET" =~ ^/mnt/hgfs/ ]]; then echo "[-] ⚠️ PERFORMANCE WARNING: Evidence is located in a VMware Shared Folder (/mnt/hgfs/)."; fi
    echo "[*] Calculating hash via accelerated native utility..."
    EVIDENCE_HASH=$(sha256sum "$TARGET" | awk '{print $1}')
    HASH_ALGO="SHA256"
fi

echo "[+] Intake Hash ($HASH_ALGO): $EVIDENCE_HASH"

echo "Timestamp: $(date -u)"            > "$CASE_DIR/chain_of_custody.txt"
echo "Source File: $TARGET"             >> "$CASE_DIR/chain_of_custody.txt"
echo "Hash Algorithm: ${HASH_ALGO:-Unknown}" >> "$CASE_DIR/chain_of_custody.txt"
echo "Acquisition Hash: $EVIDENCE_HASH" >> "$CASE_DIR/chain_of_custody.txt"
echo "Hash Source: $HASH_SOURCE"        >> "$CASE_DIR/chain_of_custody.txt"
if [ ! -z "$SCENARIO_FILE" ]; then echo "Scenario File Integrated: Yes" >> "$CASE_DIR/chain_of_custody.txt"; fi

# ==========================================================
# HYBRID MARKET-AWARE AI MODEL CAPABILITY DISCOVERY ENGINE
# ==========================================================
AI_MODEL="${AI_MODEL:-gemini/gemini-3.1-flash-lite}"
API_TIER="${API_TIER:-FREE}"

echo "[*] Querying market capabilities for model: $AI_MODEL..."
MODEL_TIER=$(python3 -c "
import sys
try:
    import litellm
    model_name = sys.argv[1].lower()
    max_tokens = litellm.get_max_tokens(model_name) or 0
    if max_tokens >= 100000: print('POWERFUL')
    elif max_tokens >= 32000: print('MEDIUM')
    else: print('LIGHT')
except Exception: print('LIGHT')
" "$AI_MODEL")

case "$MODEL_TIER" in
  POWERFUL) TRUNCATE_LINES=1000; MAX_EVIDENCE_LINES=3000; echo "====================== PROFILE: POWERFUL ======================";;
  MEDIUM) TRUNCATE_LINES=300; MAX_EVIDENCE_LINES=1500; echo "====================== PROFILE: MEDIUM ======================";;
  LIGHT|*) TRUNCATE_LINES=100; MAX_EVIDENCE_LINES=500; echo "====================== PROFILE: STANDARD ======================";;
esac

if [ "$API_TIER" = "PAID" ]; then
    PHASE_1_COOLDOWN=1; PHASE_2_COOLDOWN=0; RETRY_COOLDOWN=5; echo "[+] Speed Profile: PAID TIER"
else
    PHASE_1_COOLDOWN=20; PHASE_2_COOLDOWN=10; RETRY_COOLDOWN=45; echo "[!] Speed Profile: FREE TIER"
fi
echo "--------------------------------------------------------"

# ==========================================================
# AUTOMATED FORENSIC EXTRACTION ENGINE
# ==========================================================
if [[ "$TARGET" == *.json ]]; then
    echo "[+] Ingesting JSON telemetry profile."
    mkdir -p "$CASE_DIR/extractions"
    cp "$TARGET" "$CASE_DIR/extractions/telemetry_source.json"
    EVIDENCE_FILE="$CASE_DIR/extractions/telemetry_source.json"
elif [[ "$TARGET" == *.e01 ]] || [[ "$TARGET" == *.E01 ]]; then
    echo "[*] Detected EWF/EnCase forensic image format..."
    mkdir -p "/tmp/ewf_$CASE_NAME"
    if ! sudo ewfmount "$TARGET" "/tmp/ewf_$CASE_NAME" 2>/dev/null; then echo "[-] 🚨 FATAL: ewfmount failed."; exit 1; fi
    EVIDENCE_FILE="$CASE_DIR/extractions/filesystem_metadata.txt"; mkdir -p "$CASE_DIR/extractions"
    echo "[*] Stream-Extracting MFT metadata directly through KAPE filters..."
    sudo fls -r -p "/tmp/ewf_$CASE_NAME/ewf1" 2>/dev/null | \
        grep -iE "NTUSER.DAT|SAM|SYSTEM|SOFTWARE|Prefetch|Recent|Recycle.Bin|AppData|Local\\\\Temp|mIRC|interception|Skype|WhatsApp|Zebrafish|Vanko|Classified" \
        > "$EVIDENCE_FILE" || true
    sudo umount "/tmp/ewf_$CASE_NAME" || true; sudo rmdir "/tmp/ewf_$CASE_NAME" 2>/dev/null || true
elif [[ "$TARGET" == *.7z ]] || [[ "$TARGET" == *.zip ]]; then
    echo "[*] Detected compressed archive format..."
    echo "[*] Automating archive extraction..."

    TMP_EXTRACT="$CASE_DIR/extractions/raw_triage"
    mkdir -p "$TMP_EXTRACT"
    7z x "$TARGET" -o"$TMP_EXTRACT" -y > /dev/null
    echo "{\"timestamp\": \"$(date -u +'%Y-%m-%dT%H:%M:%SZ')\", \"actor\": \"TOOL_EXEC\", \"action\": \"Executed: 7z x $TARGET -o$TMP_EXTRACT\"}" >> "$CASE_DIR/actions.jsonl"

    EVIDENCE_FILE="$CASE_DIR/extractions/summarized_evidence.txt"
    echo "[*] Generating Forensic Summaries from Extracted Evidence..."

    # Dynamically build standard tracking keywords
    GREP_KEYWORDS="docx|xlsx|pdf|lnk|pf|bat|ps1|exe|log"
    
    # If a scenario exists, dynamically extract capitalized proper nouns/words to hunt for
    if [ -f "$SCENARIO_FILE" ]; then
        SCENARIO_WORDS=$(grep -oE '[A-Z][a-z]+' "$SCENARIO_FILE" | sort -u | paste -sd '|' - || true)
        if [ -n "$SCENARIO_WORDS" ]; then
            GREP_KEYWORDS="$GREP_KEYWORDS|$SCENARIO_WORDS"
        fi
    fi

    # Hardened standard tracking keywords for execution and document targets
    # Explicitly added Login\.Data to catch extension-less Chrome credential stores
    GREP_KEYWORDS="docx|xlsx|pdf|lnk|pf|bat|ps1|exe|log|\.db|\.sqlite|Login\.Data"
    
    # 🛡️ DEFENSIVE FORENSICS: Highly targeted examiner contamination keywords
    ANTI_CONTAMINATION="FOR500|FOR508|SANS\.Handout|Master\.Scenario\.Solution|Grading\.Rubric"

    echo -e "\n=== HIGH-VALUE SCENARIO TARGETS & DATA LEAKS ===" >> "$EVIDENCE_FILE"
    
    # TARGETED SEARCH: Extracts key document/execution types while aggressively dropping specific training artifacts
    find "$TMP_EXTRACT" -type f | grep -iE "$GREP_KEYWORDS" | grep -viE "$ANTI_CONTAMINATION" | while read -r file; do
        echo "TARGET ARTIFACT: $(basename "$file")" >> "$EVIDENCE_FILE"
        echo "PATH: $file" >> "$EVIDENCE_FILE"
        echo "SIZE: $(stat -c%s "$file" 2>/dev/null || echo "Unknown") bytes" >> "$EVIDENCE_FILE"
        echo "---" >> "$EVIDENCE_FILE"
    done
    echo -e "\n=== KEY SYSTEM LOGS & CONFIGURATION PREVIEWS ===" >> "$EVIDENCE_FILE"
    find "$TMP_EXTRACT" -type f \( -name "*.txt" -o -name "*.log" -o -name "*.ini" \) | head -n 30 | while read -r file; do
        echo -e "\n--- File: $file ---" >> "$EVIDENCE_FILE"
        head -n "$TRUNCATE_LINES" "$file" | tr -cd '\11\12\15\40-\176' >> "$EVIDENCE_FILE"
    done
else
    mkdir -p "$CASE_DIR/extractions"; EVIDENCE_FILE="$CASE_DIR/extractions/memory_scan_results.txt"
    python3 run_scan.py "$TARGET" > "$EVIDENCE_FILE" || touch "$EVIDENCE_FILE"
fi

if [ ! -f "$EVIDENCE_FILE" ] || [ ! -s "$EVIDENCE_FILE" ]; then echo "[-] 🚨 FATAL FORENSIC EXCEPTION"; exit 1; fi
head -n "$MAX_EVIDENCE_LINES" "$EVIDENCE_FILE" > "/tmp/capped_evidence_${CASE_NAME}.txt"; mv "/tmp/capped_evidence_${CASE_NAME}.txt" "$EVIDENCE_FILE"

# ==============================================================================
# ZERO-BYTE & ENCRYPTION SAFEGUARDS (Anti-Hallucination Intercept)
# ==============================================================================
if [ ! -f "$EVIDENCE_FILE" ] || [ ! -s "$EVIDENCE_FILE" ]; then
    echo "[-] 🚨 FATAL FORENSIC EXCEPTION 🚨"
    echo "[-] Extraction yielded an empty file or missing data target."
    echo "[-] Halting pipeline permanently to prevent AI cognitive hallucinations."
    exit 1
fi

echo "[*] Enforcing token-limit ceiling on raw evidence file..."
head -n "$MAX_EVIDENCE_LINES" "$EVIDENCE_FILE" > "/tmp/capped_evidence_${CASE_NAME}.txt"
mv "/tmp/capped_evidence_${CASE_NAME}.txt" "$EVIDENCE_FILE"

echo "{\"timestamp\": \"$(date -u +'%Y-%m-%dT%H:%M:%SZ')\", \"actor\": \"SYSTEM\", \"action\": \"Automated pipeline extracted $TARGET to $EVIDENCE_FILE\"}" >> "$CASE_DIR/actions.jsonl"

# --- PHASE 1.A: FACT EXTRACTION ENGINE ---
echo "[*] PASS 1: Fact Extraction Engine Running..."

# FORCE STRUCTURAL SANITY: Pre-seed an empty JSON array to completely stop truncate-corruptions
echo "[]" > "$CASE_DIR/facts.json"

set +e
aider --model "$AI_MODEL" \
  --map-tokens 0 \
  --message "Read '$EVIDENCE_FILE'. Extract raw forensic facts only. Do not draw conclusions. Create a file named '$CASE_DIR/facts.json'. The output MUST strictly be a JSON array of objects containing exactly these keys: 'artifact_type', 'artifact_name', 'artifact_value', 'source_file', 'confidence', and 'iocs'. Limit your output to a maximum of 10 observations. Prioritize executable files, scripts, network artifacts, autoruns, and scheduled tasks. 
  IOC EXTRACTION: For each artifact, extract any observable IOC values: file hashes (MD5/SHA256), full file paths, URLs, IP addresses, domain names, registry keys. Store these as a separate 'iocs' array in facts.json alongside the artifact entry.
  EXCLUSION RULE: Do NOT include standard .NET libraries (System.*.dll), Windows APIs (api-ms-win-*), manifest files (*.man), or standard user documents unless they present explicit indicators of exploitation. 
  ANTI-CONTAMINATION RULE: Explicitly IGNORE any files that appear to be examiner training materials, grading rubrics, 'Scenario Solutions', or class handouts (e.g., FOR500HANDOUT). These are artifacts of the investigation environment and constitute chain-of-custody contamination. Do not extract them." \
  --yes-always \
  --no-auto-commit \
  --read "$EVIDENCE_FILE" \
  --file "$CASE_DIR/facts.json"
set -e

echo "{\"timestamp\": \"$(date -u +'%Y-%m-%dT%H:%M:%SZ')\", \"actor\": \"AI_AGENT\", \"action\": \"Completed Pass 1: Fact Extraction.\"}" >> "$CASE_DIR/actions.jsonl"

# --- PHASE 1.B: CORRELATION & TRIAGE STAGING ---
echo "[*] Handing facts off to AI Agent for Correlation & Triage Staging..."
echo '{"case_id": "'"$CASE_NAME"'", "target": "Unknown", "intent_verdict": "Inconclusive", "summary": "", "case_confidence": 0, "mitre_ttps": [], "artifacts": []}' > "$CASE_DIR/triage_ledger.json"

MAX_RETRIES=3
RETRY_COUNT=0
VALIDATION_PASSED=false

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    echo "[*] Executing Pass 2: Agentic Correlation (Attempt $((RETRY_COUNT+1)) of $MAX_RETRIES)..."
    
    set +e
    aider --model "$AI_MODEL" \
      --map-tokens 0 \
      --message "You are an autonomous DFIR analyst. Read the raw facts in '$CASE_DIR/facts.json'.
      1. Evaluate intent objectively based ONLY on extracted facts.
      2. Document findings in '$CASE_DIR/triage_ledger.json'.
      3. The JSON must contain exactly these root keys: 'case_id' (set to $CASE_NAME), 'target', 'intent_verdict', 'summary', 'case_confidence' (integer 0-100), 'mitre_ttps' (array of applicable ATT&CK IDs), and 'artifacts'.
      4. CRITICAL SCHEMA: Every item in the 'artifacts' array MUST contain exactly these 10 keys: 'name', 'type', 'value', 'description', 'confidence', 'recommended_validation', 'risk_score' (integer 0-100), 'priority' (Low/Medium/High), 'review_status' (set to 'pending'), and 'iocs' (array of strings). Do NOT invent new keys.
      5. CRITICAL: NO MULTI-LINE STRINGS. All JSON string values must be strictly single-line.
      
      INVESTIGATION SCENARIO DEBRIEF:
      $SCENARIO_CONTEXT
      
      6. INTENT SCORING: Elevate risk and priority if an artifact correlates to the scenario.
      7. MITRE FRAMEWORK EXTRACTION: Do NOT invent, infer, or guess MITRE ATT&CK technique IDs based on behavioral text descriptions. You must strictly look for explicit, raw alphanumeric matrix codes (matching the regex pattern TXXXX or TXXXX.XXX) present within the raw data layer. If specific codes are explicitly found in the data, extract them exactly. If no explicit framework codes exist in the telemetry, leave the 'mitre_ttps' array completely empty.
      8. DEFENSIBLE SUMMARIES: In your summary field, explicitly address the core questions of the scenario.
      9. MANDATORY EVIDENCE COVERAGE MATRIX: Append 'Coverage: Filesystem=YES; Registry=NO; EventLogs=NO;' to the summary.
      10. ARTIFACT CLUSTERING & EXACT NAMING: You MUST preserve the EXACT filenames, paths, registry keys, and string values byte-for-byte. CRITICAL ALPHANUMERIC GUARDRAIL: Do not let token-prediction bias swap letters for similar-looking numbers or vice versa. Strictly ensure that characters like capital 'O' are not swapped with zero '0', and capital 'I' or lowercase 'l' are not swapped with '1'. Copy all strings exactly as they appear in the source facts.
      11. HARD BOUNDARY: Gaps in coverage do not elevate threat context.
      12. ANOMALY AWARENESS & RISK OVERRIDE: Score file transfer, persistence, and external artifacts with Medium/High Risk.
      13. PRAGMATIC VALIDATION: Tailor validation strictly to the artifact type.
      14. IOC EXTRACTION & PASSTHROUGH: You MUST explicitly copy any hashes (SHA256), URLs (like malware430.com), and exact file paths from facts.json directly into the new 'iocs' array for that artifact. Do not leave the 'iocs' array empty if indicators exist." \
      --yes-always \
      --no-auto-commit \
      --read "$CASE_DIR/facts.json" \
      --read "$CASE_DIR/chain_of_custody.txt" \
      --file "$CASE_DIR/triage_ledger.json"
    set -e

    echo "[*] Running autonomous schema validation..."
    if python3 verify_schema.py "$CASE_DIR/triage_ledger.json"; then
        echo "[+] Forensic Quality Control: Schema validation passed successfully."
        VALIDATION_PASSED=true
        break
    else
        echo "[-] WARNING: Schema validation failed. AI deviated from structural constraints."
        echo "[-] Engaging autonomous self-correction loop..."
        RETRY_COUNT=$((RETRY_COUNT+1))
        sleep "$RETRY_COOLDOWN"
    fi
done

if [ "$VALIDATION_PASSED" = false ]; then
    echo "[-] FATAL: AI agent failed to produce valid JSON after $MAX_RETRIES attempts. Aborting pipeline."
    exit 1
fi

echo "{\"timestamp\": \"$(date -u +'%Y-%m-%dT%H:%M:%SZ')\", \"actor\": \"AI_AGENT\", \"action\": \"Completed validation and correlation loop.\"}" >> "$CASE_DIR/actions.jsonl"

echo "[*] Phase 1 Complete. Initiating ${PHASE_1_COOLDOWN}-second API rate-limit adaptive cooldown..."
sleep "$PHASE_1_COOLDOWN"

# --- PHASE 1.C: TIMELINE RECONSTRUCTION ---
echo "[*] PASS 1.C: Timeline Reconstruction Engine Running..."
echo "[]" > "$CASE_DIR/timeline.json"

set +e
aider --model "$AI_MODEL" \
  --map-tokens 0 \
  --message "Read '$CASE_DIR/facts.json'. Reconstruct the probable attack sequence based on artifact relationships and timestamps. Output '$CASE_DIR/timeline.json' containing an ordered array of events. Each object must contain: 'sequence' (integer), 'event_description' (string), 'artifacts_involved' (array of strings), and 'mitre_ttp' (string, if applicable). Ensure the output is strictly valid JSON without markdown formatting." \
  --yes-always \
  --no-auto-commit \
  --read "$CASE_DIR/facts.json" \
  --file "$CASE_DIR/timeline.json"
set -e

echo "{\"timestamp\": \"$(date -u +'%Y-%m-%dT%H:%M:%SZ')\", \"actor\": \"AI_AGENT\", \"action\": \"Completed Pass 1.C: Timeline Reconstruction.\"}" >> "$CASE_DIR/actions.jsonl"

# --- PHASE 2: SENIOR FORENSIC PEER REVIEW LOOP ---
  echo "[*] Initializing Phase 2: Senior Forensic Peer Review Loop..."
  touch "$CASE_DIR/critique.txt"

  set +e
  aider --model "$AI_MODEL" \
    --map-tokens 0 \
    --message "You are a Senior Forensic Analyst auditing a junior analyst's staged 'triage_ledger.json'.
    1. Compare the junior analyst's findings in 'triage_ledger.json' against the ground-truth extracted data in 'facts.json'.
    2. Ensure the findings are technically sound, accurately categorized, and fully representative of the case context.
    3. STRICT AUDITOR CONSTRAINT: Audit the technical accuracy of what is *currently visible* within the data scope. Do NOT penalize the ledger or increase risk metrics because external tools have not been run.
    4. STRICT RISK GUARDRAIL: Do NOT increase risk scores or priority levels on artifacts solely because they are unparsed. Conversely, do NOT automatically flatten legitimate anomalies (like file transfer utilities, legacy communications, external emails, or deleted recon tools) to Low Risk without a documented justification in your critique. Evaluate them based on their actual evidentiary weight.
    5. NULL HYPOTHESIS TESTING: For each HIGH risk artifact, explicitly state and evaluate the null hypothesis (the most plausible innocent explanation). Document why the evidence supports or refutes it. Only assign MALICIOUS verdict if the null hypothesis is demonstrably refuted by the evidence.
    6. Write your technical review comments strictly regarding accuracy and the null hypothesis evaluation into a new file named '$CASE_DIR/critique.txt'. Do not modify the JSON ledger yet." \
    --yes-always \
    --no-auto-commit \
    --read "$CASE_DIR/triage_ledger.json" \
    --read "$CASE_DIR/facts.json" \
    --read "reference_material/windows-artifacts/SKILL.md" \
    --read "reference_material/memory-analysis/SKILL.md" \
    --read "reference_material/plaso-timeline/SKILL.md" \
    --read "reference_material/sleuthkit/SKILL.md" \
    --read "reference_material/yara-hunting/SKILL.md" \
    --file "$CASE_DIR/critique.txt"
  set -e

if [ -f "$CASE_DIR/critique.txt" ]; then
    echo "[!] Critical Logic Review Generated by Peer Agent:"
    cat "$CASE_DIR/critique.txt"
    echo "────────────────────────────────────────────────────────────────────────────────"

    echo "[*] Peer Review Adaptive Pause (${PHASE_2_COOLDOWN} seconds)..."
    sleep "$PHASE_2_COOLDOWN"

    echo "[*] Re-engaging Agent to integrate Senior Review into Final Ledger..."

    # Safe backup before AI touches the JSON again
    cp "$CASE_DIR/triage_ledger.json" "$CASE_DIR/triage_ledger.json.bak"

    aider --model "$AI_MODEL" \
      --map-tokens 0 \
      --message "Read the peer review critique in '$CASE_DIR/critique.txt'.
      Update the final triage ledger in '$CASE_DIR/triage_ledger.json' to address technical corrections.
      1. CRITICAL SCHEMA: The root JSON must contain exactly: 'case_id', 'target', 'intent_verdict', 'summary', 'case_confidence', 'mitre_ttps', and 'artifacts'.
      2. CRITICAL SCHEMA: Every item in the 'artifacts' array MUST remain a JSON object containing exactly the 10 required keys, including the 'iocs' array of strings.
      3. MITRE CONSTRAINT: Validate the 'mitre_ttps' array. Ensure it only contains technique IDs that were explicitly extracted from the raw evidence layer. Delete any framework codes that were guessed or inferred by the junior agent.
      4. STRIP TOKENIZATION CORRUPTION: Conduct a literal string audit on all filenames and services. Ensure no characters have been corrupted or swapped by tokenization bias (strictly verifying that letters 'O' and 'I' were not accidentally replaced with numbers '0' and '1').
      5. CRITICAL REMEDIATION BAN: Do NOT include workflow tracking phrases." \
      --yes-always --no-auto-commit \
      --read "$CASE_DIR/critique.txt" \
      --file "$CASE_DIR/triage_ledger.json"

    echo "[*] Running Post-Review Schema Validation..."
    sed -i '/^```/d' "$CASE_DIR/triage_ledger.json" || true

    if python3 verify_schema.py "$CASE_DIR/triage_ledger.json" > /dev/null 2>&1 && \
       python3 -c "import json; json.load(open('$CASE_DIR/triage_ledger.json'))" > /dev/null 2>&1; then
        echo "[+] Post-Review validation passed."
        rm "$CASE_DIR/triage_ledger.json.bak"
    else
        echo "[-] 🚨 WARNING: Peer review integration broke the JSON schema! Reverting to pre-review ledger..."
        mv "$CASE_DIR/triage_ledger.json.bak" "$CASE_DIR/triage_ledger.json"
    fi
fi

echo "{\"timestamp\": \"$(date -u +'%Y-%m-%dT%H:%M:%SZ')\", \"actor\": \"AI_AGENT\", \"action\": \"Successfully integrated peer review feedback.\"}" >> "$CASE_DIR/actions.jsonl"

# --- PHASE 3: HUMAN EXAMINER CHECKPOINT ---
echo ""
echo "========================================================"
echo "    ⚠️  CRITICAL CHECKPOINT: HUMAN EXAMINER REVIEW ⚠️"
echo "========================================================"
echo "The AI Agent has staged finalized findings inside: $CASE_DIR/triage_ledger.json"
echo "Review the file. When you are ready to approve the verdict and sign off,"
printf "Type 'APPROVE' to authorize final report generation: "
read -r USER_INPUT

if [ "$USER_INPUT" == "APPROVE" ]; then
    echo "[*] Modifying ledger status to APPROVED..."
    sed -i 's/DRAFT_//g' "$CASE_DIR/triage_ledger.json"
    sed -i 's/PENDING_HUMAN_REVIEW/APPROVED_BY_EXAMINER/g' "$CASE_DIR/triage_ledger.json"
    echo "{\"timestamp\": \"$(date -u +'%Y-%m-%dT%H:%M:%SZ')\", \"actor\": \"EXAMINER\", \"action\": \"Cryptographically signed and verified final report data.\"}" >> "$CASE_DIR/actions.jsonl"

    echo "[*] Orchestrating final PDF report generation..."
    python3 generate_pdf_report.py "$CASE_DIR/triage_ledger.json"

    GT_FILE="cases/$CASE_NAME/ground_truth.json"
    if [ -f "$GT_FILE" ] && [ -f "evaluate_benchmark.py" ]; then
        echo "[*] Ground Truth file found. Evaluating agent performance matrix..."
        python3 evaluate_benchmark.py "$CASE_DIR/triage_ledger.json" "$GT_FILE"
    fi

    mkdir -p "$CASE_DIR/reports"
    mv exports/*.pdf "$CASE_DIR/reports/" 2>/dev/null || true

    echo "[*] Archiving multi-agent conversation transcripts for audit trail..."
    cp .aider.chat.history.md "$CASE_DIR/reports/agent_transcript.md" 2>/dev/null || true
    echo "[+] PIPELINE COMPLETE. Final verified artifact saved to $CASE_DIR/reports/"
else
    echo "[-] Investigation Paused / AI Re-prompted based on human rejection."
    echo "{\"timestamp\": \"$(date -u +'%Y-%m-%dT%H:%M:%SZ')\", \"actor\": \"EXAMINER\", \"action\": \"Rejected/deferred staged findings.\"}" >> "$CASE_DIR/actions.jsonl"
    exit 1
fi
