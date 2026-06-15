#!/bin/bash
set -e # Abort immediately if any command fails

# ANSI Color Codes for Enterprise Terminal UI
CYAN='\033[0;36m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
BOLD='\033[1m'
NC='\033[0m' # No Color

if [ -z "$1" ]; then
    echo -e "${YELLOW}Usage: ./analyze.sh <path_to_evidence> [path_to_scenario_txt]${NC}"
    exit 1
fi

TARGET=$1
SCENARIO_FILE=$2

# Verify file exists and resolve absolute path to prevent traversal attacks
if [ ! -f "$TARGET" ]; then
    echo -e "${RED}[-] 🚨 FATAL: Target file '$TARGET' does not exist.${NC}"
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
        echo -e "${YELLOW}[!] Existing case directory detected. Purging old artifacts to ensure forensic isolation...${NC}"
        rm -rf "$CASE_DIR"
    else
        echo -e "${RED}[-] 🚨 FATAL: Directory safety check failed. Aborting deletion.${NC}"
        exit 1
    fi
fi

mkdir -p "$CASE_DIR"
trap 'rm -f "/tmp/raw_mft_dump_${CASE_NAME}.txt"; sudo rmdir "/tmp/ewf_${CASE_NAME}" 2>/dev/null || true' EXIT

# Handle Scenario Document ingestion if present
SCENARIO_CONTEXT="No background scenario document provided for this case. Perform standard baseline triage."
if [ -n "$SCENARIO_FILE" ] && [ -f "$SCENARIO_FILE" ]; then
    echo -e "${GREEN}[+] Scenario document detected. Ingesting background investigation context...${NC}"
    cp "$SCENARIO_FILE" "$CASE_DIR/investigation_scenario.txt"
    SCENARIO_CONTEXT=$(cat "$CASE_DIR/investigation_scenario.txt")
fi

# ==============================================================================
# PRE-FLIGHT DEPENDENCY CHECK
# ==============================================================================
echo -e "${CYAN}[*] Running pre-flight checks...${NC}"
if [ ! -f "verify_schema.py" ]; then echo -e "${RED}[-] 🚨 FATAL: verify_schema.py is missing.${NC}"; exit 1; fi

# ==============================================================================
# FORENSIC CRYPTOGRAPHIC INTAKE (Pro-Grade Chain of Custody)
# ==============================================================================
echo -e "${CYAN}[*] Resolving cryptographic hash of original evidence...${NC}"
EVIDENCE_HASH=""
HASH_ALGO="SHA256"
HASH_SOURCE="Independently calculated via native sha256sum"

if { [[ "$TARGET" == *.e01 ]] || [[ "$TARGET" == *.E01 ]]; } && command -v ewfinfo >/dev/null 2>&1; then
    echo -e "${GREEN}[+] Detected E01 format. Instantly extracting embedded acquisition hash...${NC}"
    HASH_LINE=$(ewfinfo "$TARGET" | grep -iE "hash stored in file|SHA256 hash|MD5 hash" | head -n 1)
    EVIDENCE_HASH=$(echo "$HASH_LINE" | awk -F': ' '{print $2}' | tr -d ' ')
    if [ ${#EVIDENCE_HASH} -eq 64 ]; then
        HASH_ALGO="SHA256"
    elif [ ${#EVIDENCE_HASH} -eq 32 ]; then
        HASH_ALGO="MD5"
    else
        HASH_ALGO=$(echo "$HASH_LINE" | grep -oiE "SHA256|MD5" | tr '[:lower:]' '[:upper:]')
    fi
    HASH_SOURCE="E01 embedded acquisition hash (not independently recalculated)"
fi

if [ -z "$EVIDENCE_HASH" ]; then
    if [[ "$TARGET" =~ ^/mnt/hgfs/ ]]; then
        echo -e "${YELLOW}[-] ⚠️ PERFORMANCE WARNING: Evidence is located in a VMware Shared Folder (/mnt/hgfs/).${NC}"
        echo -e "${YELLOW}[-] Hashing will be significantly delayed by hypervisor disk I/O serialization.${NC}"
    fi
    echo -e "${CYAN}[*] Calculating hash via accelerated native utility...${NC}"
    EVIDENCE_HASH=$(sha256sum "$TARGET" | awk '{print $1}')
    HASH_ALGO="SHA256"
fi

echo -e "${GREEN}[+] Intake Hash ($HASH_ALGO): $EVIDENCE_HASH${NC}"

echo "Timestamp: $(date -u)"                   > "$CASE_DIR/chain_of_custody.txt"
echo "Source File: $TARGET"                    >> "$CASE_DIR/chain_of_custody.txt"
echo "Hash Algorithm: ${HASH_ALGO:-Unknown}"   >> "$CASE_DIR/chain_of_custody.txt"
echo "Acquisition Hash: $EVIDENCE_HASH"        >> "$CASE_DIR/chain_of_custody.txt"
echo "Hash Source: $HASH_SOURCE"               >> "$CASE_DIR/chain_of_custody.txt"
if [ -n "$SCENARIO_FILE" ]; then
    echo "Scenario File Integrated: Yes"       >> "$CASE_DIR/chain_of_custody.txt"
fi

# ==========================================================
# HYBRID MARKET-AWARE AI MODEL CAPABILITY DISCOVERY ENGINE
# ==========================================================
AI_MODEL="${AI_MODEL:-gemini/gemini-3.1-flash-lite}"
API_TIER="${API_TIER:-FREE}"

echo -e "${CYAN}[*] Querying market capabilities for model: $AI_MODEL...${NC}"
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
  POWERFUL) TRUNCATE_LINES=2000; MAX_EVIDENCE_LINES=5000; echo -e "${BOLD}====================== PROFILE: POWERFUL ======================${NC}";;
  MEDIUM)   TRUNCATE_LINES=1000;  MAX_EVIDENCE_LINES=3000; echo -e "${BOLD}====================== PROFILE: MEDIUM ======================${NC}";;
  LIGHT|*)  TRUNCATE_LINES=500;  MAX_EVIDENCE_LINES=1500;  echo -e "${BOLD}====================== PROFILE: STANDARD ======================${NC}";;
esac

if [ "$API_TIER" = "PAID" ]; then
    PHASE_1_COOLDOWN=1; PHASE_2_COOLDOWN=0; RETRY_COOLDOWN=5
    echo -e "${GREEN}[+] Speed Profile: PAID TIER (delays disabled)${NC}"
else
    PHASE_1_COOLDOWN=20; PHASE_2_COOLDOWN=10; RETRY_COOLDOWN=45
    echo -e "${YELLOW}[!] Speed Profile: FREE TIER (enforcing rate-limit delays)${NC}"
fi
echo "--------------------------------------------------------"

# ==========================================================
# AUTOMATED FORENSIC EXTRACTION ENGINE
# ==========================================================
IS_JSON_TELEMETRY=false

if [[ "$TARGET" == *.json ]]; then
    echo -e "${GREEN}[+] Ingesting JSON telemetry profile.${NC}"
    mkdir -p "$CASE_DIR/extractions"
    cp "$TARGET" "$CASE_DIR/extractions/telemetry_source.json"
    EVIDENCE_FILE="$CASE_DIR/extractions/telemetry_source.json"
    IS_JSON_TELEMETRY=true

elif [[ "$TARGET" == *.e01 ]] || [[ "$TARGET" == *.E01 ]]; then
    echo -e "${CYAN}[*] Detected EWF/EnCase forensic image format...${NC}"
    mkdir -p "/tmp/ewf_$CASE_NAME"
    if ! sudo ewfmount "$TARGET" "/tmp/ewf_$CASE_NAME" 2>/dev/null; then
        echo -e "${RED}[-] 🚨 FATAL: ewfmount failed.${NC}"; exit 1
    fi
    EVIDENCE_FILE="$CASE_DIR/extractions/filesystem_metadata.txt"
    mkdir -p "$CASE_DIR/extractions"
    touch "$EVIDENCE_FILE"
    
    echo -e "${CYAN}[*] Discovering partition offsets via mmls...${NC}"
    OFFSETS=$(sudo mmls "/tmp/ewf_$CASE_NAME/ewf1" 2>/dev/null | grep -iE "NTFS|FAT|exFAT|Basic data|Linux|Mac" | awk '{print $3}' | grep -E '^[0-9]+$' || true)
    
    if [ -z "$OFFSETS" ]; then
        echo -e "${YELLOW}[!] No partition table found. Assuming logical image (Offset 0)...${NC}"
        OFFSETS="0"
    fi
    
    for OFFSET in $OFFSETS; do
    echo -e "${CYAN}[*] Stream-Extracting MFT metadata at sector offset $OFFSET...${NC}"
    # Stream the full directory structure, but discard massive known-benign noise directories
    sudo fls -o "$OFFSET" -r -p "/tmp/ewf_$CASE_NAME/ewf1" 2>/dev/null | \
        grep -vE "Microsoft\\\\Windows\\\\WinSxS|Google\\\\Chrome\\\\User Data\\\\Default\\\\Cache|AppData\\\\Local\\\\Microsoft\\\\Windows\\\\History" \
        >> "$EVIDENCE_FILE" || true
done

    if [ ! -s "$EVIDENCE_FILE" ]; then
        echo -e "${YELLOW}[-] WARNING: File system extraction yielded no data (possible BitLocker/FDE). Falling back to string extraction...${NC}"
        sudo strings -a "/tmp/ewf_$CASE_NAME/ewf1" | grep -iE "http://|https://|@[a-zA-Z0-9.-]+" | head -n 3000 > "$EVIDENCE_FILE" || true
    fi

    echo "{\"timestamp\": \"$(date -u +'%Y-%m-%dT%H:%M:%SZ')\", \"actor\": \"TOOL_EXEC\", \"action\": \"Executed: Streaming fls extraction with dynamic offsets\"}" >> "$CASE_DIR/actions.jsonl"
    sudo umount "/tmp/ewf_$CASE_NAME" || true
    sudo rmdir "/tmp/ewf_$CASE_NAME" 2>/dev/null || true

elif [[ "$TARGET" == *.7z ]] || [[ "$TARGET" == *.zip ]]; then
    echo -e "${CYAN}[*] Detected compressed archive format...${NC}"
    TMP_EXTRACT="$CASE_DIR/extractions/raw_triage"
    mkdir -p "$TMP_EXTRACT"
    7z x "$TARGET" -o"$TMP_EXTRACT" -y > /dev/null
    echo "{\"timestamp\": \"$(date -u +'%Y-%m-%dT%H:%M:%SZ')\", \"actor\": \"TOOL_EXEC\", \"action\": \"Executed: 7z x $TARGET -o$TMP_EXTRACT\"}" >> "$CASE_DIR/actions.jsonl"

    EVIDENCE_FILE="$CASE_DIR/extractions/summarized_evidence.txt"
    echo -e "${CYAN}[*] Generating Forensic Summaries from Extracted Evidence...${NC}"

    GREP_KEYWORDS="docx|xlsx|pdf|lnk|pf|bat|ps1|exe|log|\.db$|\.sqlite$|Login\.Data"
    ANTI_CONTAMINATION="FOR500|FOR508|SANS\.Handout|Master\.Scenario\.Solution|Grading\.Rubric"

    echo -e "\n=== HIGH-VALUE SCENARIO TARGETS & DATA LEAKS ===" >> "$EVIDENCE_FILE"
    
    find "$TMP_EXTRACT" -type f | grep -iE "$GREP_KEYWORDS" | grep -viE "$ANTI_CONTAMINATION" | while read -r file; do
        echo "TARGET ARTIFACT: $(basename "$file")" >> "$EVIDENCE_FILE"
        echo "PATH: $file"                                          >> "$EVIDENCE_FILE"
        echo "SIZE: $(stat -c%s "$file" 2>/dev/null || echo "Unknown") bytes" >> "$EVIDENCE_FILE"
        echo "---"                                                  >> "$EVIDENCE_FILE"
    done

    echo -e "\n=== KEY SYSTEM LOGS & CONFIGURATION PREVIEWS ===" >> "$EVIDENCE_FILE"
    find "$TMP_EXTRACT" -type f \( -name "*.txt" -o -name "*.log" -o -name "*.ini" \) | head -n 30 | while read -r file; do
        echo -e "\n--- File: $file ---" >> "$EVIDENCE_FILE"
        head -n "$TRUNCATE_LINES" "$file" | tr -cd '\11\12\15\40-\176' >> "$EVIDENCE_FILE"
    done

elif [[ "$TARGET" == *.pcap ]] || [[ "$TARGET" == *.pcapng ]]; then
    echo -e "${CYAN}[*] Detected Network Capture format...${NC}"
    EVIDENCE_FILE="$CASE_DIR/extractions/network_summary.txt"
    mkdir -p "$CASE_DIR/extractions"
    if command -v tshark >/dev/null 2>&1; then
        echo -e "${CYAN}[*] Extracting network telemetry via tshark (Best-Effort)...${NC}"
        
        echo -e "\n=== ENDPOINTS & PROTOCOLS ===" > "$EVIDENCE_FILE"
        tshark -r "$TARGET" -q -z endpoints,ip >> "$EVIDENCE_FILE" || true
        
        echo -e "\n=== CONNECTION TIMELINE (Sample) ===" >> "$EVIDENCE_FILE"
        tshark -r "$TARGET" -T fields -e frame.time -e ip.src -e tcp.srcport -e udp.srcport -e ip.dst -e tcp.dstport -e udp.dstport -e _ws.col.Protocol | head -n 500 >> "$EVIDENCE_FILE" || true
        
        echo -e "\n=== TOP DNS QUERIES ===" >> "$EVIDENCE_FILE"
        tshark -r "$TARGET" -Y "dns" -T fields -e ip.src -e dns.qry.name | sort | uniq -c | sort -nr | head -n 100 >> "$EVIDENCE_FILE" || true
        
        echo -e "\n=== TOP HTTP/SMTP ARTIFACTS ===" >> "$EVIDENCE_FILE"
        tshark -r "$TARGET" -Y "http || smtp" -T fields \
            -e ip.src -e ip.dst -e http.host -e http.request.uri -e http.user_agent -e http.cookie \
            -e smtp.req.parameter | sort | uniq -c | sort -nr | head -n 150 >> "$EVIDENCE_FILE" || true

        echo -e "\n=== TLS SNI ARTIFACTS ===" >> "$EVIDENCE_FILE"
        tshark -r "$TARGET" -Y "tls.handshake.type == 1" -T fields \
            -e ip.src -e ip.dst -e tls.handshake.extensions_server_name | sort | uniq -c | sort -nr | head -n 100 >> "$EVIDENCE_FILE" || true
    else
        echo -e "${YELLOW}[!] tshark not found. Falling back to deep string extraction...${NC}"
        strings "$TARGET" | grep -iE "http://|https://|@[a-zA-Z0-9.-]+|user-agent:|cookie:|host:" | sort | uniq -c | sort -nr | head -n 300 > "$EVIDENCE_FILE" || true
    fi
    echo "{\"timestamp\": \"$(date -u +'%Y-%m-%dT%H:%M:%SZ')\", \"actor\": \"TOOL_EXEC\", \"action\": \"Parsed structured PCAP telemetry.\"}" >> "$CASE_DIR/actions.jsonl"

else
    mkdir -p "$CASE_DIR/extractions"
    EVIDENCE_FILE="$CASE_DIR/extractions/memory_scan_results.txt"
    python3 run_scan.py "$TARGET" > "$EVIDENCE_FILE" || touch "$EVIDENCE_FILE"
fi

if [ ! -f "$EVIDENCE_FILE" ] || [ ! -s "$EVIDENCE_FILE" ]; then
    echo -e "${RED}[-] 🚨 FATAL FORENSIC EXCEPTION 🚨${NC}"
    echo -e "${RED}[-] Extraction yielded an empty file or missing data target.${NC}"
    exit 1
fi

echo -e "${CYAN}[*] Enforcing token-limit ceiling on raw evidence file...${NC}"
head -n "$MAX_EVIDENCE_LINES" "$EVIDENCE_FILE" > "/tmp/capped_evidence_${CASE_NAME}.txt"
mv "/tmp/capped_evidence_${CASE_NAME}.txt" "$EVIDENCE_FILE"
echo "{\"timestamp\": \"$(date -u +'%Y-%m-%dT%H:%M:%SZ')\", \"actor\": \"SYSTEM\", \"action\": \"Automated pipeline extracted $TARGET to $EVIDENCE_FILE\"}" >> "$CASE_DIR/actions.jsonl"

# ==============================================================================
# --- PHASE 1.A: FACT & IOC EXTRACTION ENGINE ---
# ==============================================================================
echo -e "${CYAN}[*] PASS 1: Fact & IOC Extraction Engine Running...${NC}"
echo "[]" > "$CASE_DIR/facts.json"

if [ "$IS_JSON_TELEMETRY" = true ]; then
    echo -e "${CYAN}[*] Structured JSON input detected. Building deterministic fact graph...${NC}"
    python3 - "$EVIDENCE_FILE" "$CASE_DIR/facts.json" <<'PY'
import json
import ipaddress
import re
import sys

BENIGN_DOMAINS = {"gmail.com", "hotmail.com", "yahoo.com", "sbcglobal.net", 
                  "nist.gov", "outlook.com", "protonmail.com", "proton.me",
                  "google.com", "microsoft.com", "windows.com", "sourceforge.net",
                  "bing.com", "live.com", "office.com", "apple.com", "mozilla.org"}
FAKE_TLDS = {"exe", "dll", "zip", "ini", "bat", "ps1", "log", "txt", "pdf", "doc", "xls", "xlsx", "docx", "php", "jsp", "asp", "aspx", "sh", "py"}

src, dst = sys.argv[1], sys.argv[2]

with open(src, "r", encoding="utf-8", errors="ignore") as f:
    data = json.load(f)

facts = []
seen = set()

def add_fact(artifact_type, artifact_name, artifact_value, confidence="medium", iocs=None):
    value = str(artifact_value or "").strip()
    if not value: return
    key = (artifact_type, artifact_name, value.lower())
    if key in seen: return
    seen.add(key)
    ioc_values = []
    if iocs:
        for i in iocs:
            s = str(i).strip()
            if s and s not in ioc_values:
                ioc_values.append(s)
    facts.append({
        "artifact_type": artifact_type,
        "artifact_name": artifact_name,
        "artifact_value": value,
        "source_file": src,
        "confidence": confidence,
        "iocs": ioc_values,
    })

def find_all(pattern, text):
    return re.findall(pattern, text, flags=re.IGNORECASE)

def iter_valid_ips(text):
    for match in re.finditer(r"\b(?:\d{1,3}\.){3}\d{1,3}\b", text):
        candidate = match.group(0)
        context = text[max(0, match.start() - 16):min(len(text), match.end() + 16)].lower()
        if "firefox" in context or "safari" in context or "chrome" in context: continue
        try:
            ip_obj = ipaddress.ip_address(candidate)
        except ValueError: continue
        if ip_obj.version == 4: yield candidate

global_text = " | ".join([str(data.get("case_name", "")), str(data.get("description", "")), str(data.get("incident_type", ""))])

if data.get("incident_type"): add_fact("case_context", "Incident Type", data.get("incident_type", ""), confidence="high", iocs=[])
if data.get("description"): add_fact("case_context", "Case Description", data.get("description", ""), confidence="medium", iocs=[])

artifacts = data.get("artifacts", [])
for art in artifacts:
    a_type = str(art.get("type", "unknown")).strip() or "unknown"
    content = str(art.get("content", ""))
    anomalies = art.get("forensic_anomalies", [])
    anomaly_text = " | ".join(str(x) for x in anomalies) if isinstance(anomalies, list) else str(anomalies)
    blob = " | ".join([content, anomaly_text])
    blob_lower = blob.lower()

    for ip in iter_valid_ips(blob):
        label = "Internal IP" if "internal" in blob_lower and ip.startswith("192.168.") else "External IP" if "external" in blob_lower else "IP Address"
        add_fact("network_flow", label, ip, confidence="high", iocs=[ip])

    for mac in find_all(r"\b[0-9a-f]{2}(?::[0-9a-f]{2}){5}\b", blob):
        add_fact("network_flow", "MAC Address", mac.lower(), confidence="high", iocs=[mac.lower()])

    hashes = find_all(r"\b[0-9a-f]{32}\b|\b[0-9a-f]{64}\b", blob_lower)
    for h in hashes:
        label = "SHA256 Hash" if len(h) == 64 else "MD5 Hash"
        add_fact("file_metadata", label, h, confidence="high", iocs=[h])

    for hostname in find_all(r"ComputerName\s*(?:=|:)\s*([^\s\|]+)", blob):
        add_fact("registry", "Hostname", hostname.strip(), confidence="high", iocs=[hostname.strip()])

    for owner in find_all(r"RegisteredOwner\s*(?:=|:)\s*([^\s\|]+)", blob):
        if owner.strip(): add_fact("registry", "Registered Owner", owner.strip(), confidence="high", iocs=[])

    emails = find_all(r"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}", blob)
    for e in dict.fromkeys(emails):
        add_fact("email_header", "Observed Email", e, confidence="high", iocs=[e])
    email_domains = {e.split("@")[1].lower() for e in emails if "@" in e}
    email_domains.update(BENIGN_DOMAINS)

    domains = find_all(r"\b(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,}\b", blob_lower)
    for dom in domains:
        tld = dom.rsplit(".", 1)[-1]
        if tld in FAKE_TLDS or dom in email_domains: continue
        
        is_in_email = any(dom in e for e in emails)
        if is_in_email: continue
        
        add_fact("network_flow", "Domain", dom, confidence="medium", iocs=[dom])

    for ua in find_all(r"(?:firefox|safari|chrome|edge|ie)\s*[0-9a-zA-Z\./_-]*\s*/\s*[a-z0-9 ._-]+", blob):
        add_fact("network_flow", "User Agent", ua.strip(), confidence="medium", iocs=[])

    for ttp in find_all(r"\bT\d{4}(?:\.\d{3})?\b", blob):
        add_fact("threat_mapping", "Observed MITRE Technique", ttp.upper(), confidence="medium", iocs=[ttp.upper()])

    if anomaly_text: add_fact(a_type, "Forensic Anomaly", anomaly_text, confidence="medium", iocs=[])

    actor_name_match = re.search(r"identified\s+account\s*:\s*[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\s*[\-–—>→]+\s*([A-Za-z][A-Za-z\s'\.-]{2,80})", blob, flags=re.IGNORECASE)
    if actor_name_match:
        actor_name = re.sub(r"\s*\(.*?\)\s*$", "", actor_name_match.group(1).strip())
        add_fact("identity_attribution", "Attributed Human Actor", actor_name, confidence="high", iocs=[])

    # Extract Potential Bitcoin Wallets
    btc_wallets = find_all(r"\b(?:bc1|[13])[a-zA-HJ-NP-Z0-9]{25,39}\b", blob)
    for btc in btc_wallets:
        add_fact("financial_indicator", "Bitcoin Wallet", btc, confidence="high", iocs=[btc])

    # Extract long, potentially malicious Base64 payloads (40+ characters)
    b64_strings = find_all(r"(?:[A-Za-z0-9+/]{4}){10,}(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?", blob)
    for b64:
        if len(b64) > 50 and "==" in b64:
            add_fact("obfuscation", "Suspicious Base64 Payload", b64, confidence="medium", iocs=[])

    if not facts: add_fact("case_context", "Extraction Status", "No deterministic facts parsed from JSON telemetry", confidence="low", iocs=[])

    facts = facts[:100]
    with open(dst, "w", encoding="utf-8") as f: json.dump(facts, f, indent=2)
PY
else
    # AI Fallback Extractor
    cat .aider.chat.history.md >> "$CASE_DIR/agent_transcript.md" 2>/dev/null || true
    rm -f .aider.chat.history.md

    # Estimate token usage based on input file sizes
    INPUT_BYTES=$(wc -c < "$EVIDENCE_FILE" 2>/dev/null || echo 0)
    ESTIMATED_TOKENS=$((INPUT_BYTES / 4))

    set +e
    aider --model "$AI_MODEL" --map-tokens 0 \
      --message "Read '$EVIDENCE_FILE'. Extract raw forensic facts. Create '$CASE_DIR/facts.json' as a JSON array of objects with keys: 'artifact_type', 'artifact_name', 'artifact_value', 'source_file', 'confidence', 'iocs'. Extract all IPs, MACs, emails, domains, hashes, URLs, user agents, cookies/session identifiers, account names, and execution paths. When an entity role is inferable, encode it in 'artifact_name', e.g., 'Actor Email', 'Victim IP', 'Associated Internal IP', 'Infrastructure Domain', or 'Unknown Email'. Limit to 20 highly actionable observations." \
      --yes-always --no-auto-commit --read "$EVIDENCE_FILE" --file "$CASE_DIR/facts.json"
    set -e

    echo "{\"timestamp\": \"$(date -u +'%Y-%m-%dT%H:%M:%SZ')\", \"action\": \"aider_pass_1_extraction\", \"estimated_input_tokens\": $ESTIMATED_TOKENS, \"status\": \"completed\"}" >> "$CASE_DIR/actions.jsonl"
fi

echo "{\"timestamp\": \"$(date -u +'%Y-%m-%dT%H:%M:%SZ')\", \"actor\": \"AI_AGENT\", \"action\": \"Completed Pass 1: Fact & IOC Extraction.\"}" >> "$CASE_DIR/actions.jsonl"

# ==============================================================================
# --- PHASE 1.B: CORRELATION & TRIAGE STAGING ---
# ==============================================================================
echo -e "${CYAN}[*] Handing facts off to AI Agent for Correlation & Triage Staging...${NC}"

# 🛡️ DETERMINISTIC ZERO-EVIDENCE PROTOCOL
ZERO_EVIDENCE=false

if python3 -c "import json,sys; f=json.load(open('$CASE_DIR/facts.json')); sys.exit(0 if any(x.get('artifact_name') != 'Extraction Status' for x in f) else 1)" 2>/dev/null; then
    HAS_FACTS="yes"
else
    HAS_FACTS="no"
fi

if [ "$HAS_FACTS" == "no" ]; then
    echo -e "${RED}[-] 🚨 ZERO-EVIDENCE PROTOCOL TRIGGERED: No actionable facts extracted.${NC}"
    echo -e "${RED}[-] Generating deterministic Inconclusive ledger and bypassing AI analysis to prevent hallucinations...${NC}"
    
    ZERO_EVIDENCE=true
    
    # Write the strictly compliant ledger
    echo '{
  "case_id": "'"$CASE_NAME"'",
  "target": "Unknown",
  "intent_verdict": "Inconclusive",
  "summary": "Analysis failed due to unsupported file format or empty extraction. This does not indicate a clean system; it indicates a lack of parseable telemetry. EVIDENCE COVERAGE MATRIX: [Filesystem: NO] [Registry: NO] [EventLogs: NO] [NetworkLogs: NO]",
  "null_hypothesis": "The system may be clean, but lack of data prevents forensic verification.",
  "case_confidence": 0,
  "mitre_ttps": [],
  "artifacts": []
}' > "$CASE_DIR/triage_ledger.json"

    # Write the isolated timeline file
    echo '[{
  "sequence": 1,
  "event_description": "Timeline reconstruction failed — insufficient data.",
  "artifacts_involved": [],
  "mitre_ttp": "",
  "confidence": "Low"
}]' > "$CASE_DIR/timeline.json"
    
    # Force bypass of the Phase 1.B AI loop
    VALIDATION_PASSED=true
    MAX_RETRIES=0 
else
    # Initialize the blank ledger for the AI
    echo '{"case_id": "'"$CASE_NAME"'", "target": "Unknown", "intent_verdict": "Inconclusive", "summary": "", "null_hypothesis": "", "case_confidence": 0, "mitre_ttps": [], "artifacts": []}' > "$CASE_DIR/triage_ledger.json"
    MAX_RETRIES=3
    VALIDATION_PASSED=false
fi

RETRY_COUNT=0

# AMNESIA PROTOCOL
cat .aider.chat.history.md >> "$CASE_DIR/agent_transcript.md" 2>/dev/null || true
rm -f .aider.chat.history.md

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    echo -e "${CYAN}[*] Executing Pass 2: Agentic Correlation (Attempt $((RETRY_COUNT+1)) of $MAX_RETRIES)...${NC}"

    INPUT_BYTES=$(wc -c < "$CASE_DIR/facts.json" 2>/dev/null || echo 0)
    ESTIMATED_TOKENS=$((INPUT_BYTES / 4))

    set +e
    aider --model "$AI_MODEL" \
      --map-tokens 0 \
      --message "You are an autonomous DFIR analyst. Read '$CASE_DIR/facts.json' and document findings in '$CASE_DIR/triage_ledger.json'.

      SCHEMA REQUIREMENTS (strictly enforced by automated validator):
      Root keys EXACTLY: case_id (=$CASE_NAME), target, intent_verdict, summary, null_hypothesis, case_confidence, mitre_ttps, artifacts.
      Each artifact object EXACTLY: name, type, value, description, presence_confidence (Low/Medium/High), execution_confidence (None/Low/Medium/High), intent_confidence (None/Low/Medium/High), recommended_validation, risk_score (int 0-100), priority (Low/Medium/High), review_status (\"pending\"), iocs (array of strings).
      CRITICAL FORMATTING: Output all numbers and risk scores as plain, bare integers (e.g., 85). Render everything as strict, plain text. No LaTeX.

      INVESTIGATION CONTEXT:
      $SCENARIO_CONTEXT

      CRITICAL FORENSIC RULES:
      1. NULL HYPOTHESIS FIRST: Assume the system is benign until evidence disproves it. Known-good hashes, baseline OS files, and forensic image hashes are affirmative evidence supporting the null hypothesis. They are NOT Indicators of Compromise (IOCs).
      2. METADATA IS NOT A FINDING: Do not score the Target IP address, Memory Image Hash, or System Hostname as findings. These are administrative data.
      3. EVIDENCE REQUIREMENT: Every finding must reference at least one concrete artifact (e.g., file path, registry key, network connection). If no supporting artifact exists, you MUST NOT generate a finding. Do not infer or speculate.
      4. EMPTY STATES ARE REQUIRED FOR BENIGN HOSTS: If no malicious activity is found, leave the arrays empty: {\"artifacts\": [], \"mitre_ttps\": []}. Do not invent data to mitigate schema population bias.
      5. INTENT VERDICT: Evaluate objectively. Avoid model default bias for C2/Exfiltration. 
      6. THREE-TIER CONFIDENCE ALIGNMENT: If the final 'intent_verdict' is 'BENIGN' or 'Inconclusive', NO artifact can have 'intent_confidence' of 'High'. They must match the verdict.
      7. MITRE ACCURACY: Anti-forensic utilities map to T1070. Sniffing maps to T1040. Treat all as 'Candidate TTPs'. Do not map GUI utilities (Task Manager) to T1059.
      8. FORENSIC DEFENSIBILITY & LANGUAGE LOCKDOWN: You are strictly forbidden from using definitive legal language. BAN: 'confirms', 'proves', 'suspect', 'attacker'. USE: 'evidence indicates', 'artifacts are consistent with'.
      9. PRESENCE VS EXECUTION: Do not state a tool was 'utilized' unless Prefetch, Shimcache, Amcache, or Event Logs explicitly confirm it. Else state: 'Presence consistent with availability for use.'" \
      --yes-always --no-auto-commit \
      --read "$CASE_DIR/facts.json" \
      --read "$CASE_DIR/chain_of_custody.txt" \
      --file "$CASE_DIR/triage_ledger.json"
    AI_EXIT=$?
    set -e

    echo "{\"timestamp\": \"$(date -u +'%Y-%m-%dT%H:%M:%SZ')\", \"action\": \"aider_pass_2_correlation\", \"estimated_input_tokens\": $ESTIMATED_TOKENS, \"status\": \"completed\"}" >> "$CASE_DIR/actions.jsonl"

    if [ $AI_EXIT -ne 0 ]; then
        echo -e "${YELLOW}[-] WARNING: AI correlation pass failed (exit code: $AI_EXIT). Retrying...${NC}"
        RETRY_COUNT=$((RETRY_COUNT+1))
        echo -ne "${YELLOW}[*] Retrying in: ${NC}"
	for i in $(seq "$RETRY_COOLDOWN" -1 1); do
	    echo -ne "${YELLOW}$i... ${NC}"
	    sleep 1
	done
	echo -e "${GREEN}Executing...${NC}"
        continue
    fi

    echo -e "${CYAN}[*] Running autonomous schema validation...${NC}"
    sed -i '/^```/d' "$CASE_DIR/triage_ledger.json" || true

    # Execute the isolated validation module
    python3 run_validation.py "$CASE_DIR/facts.json" "$CASE_DIR/triage_ledger.json"
    
    set +e
    python3 verify_schema.py "$CASE_DIR/triage_ledger.json" > /dev/null 2>&1; SCHEMA_EXIT=$?
    python3 -c "import json; json.load(open('$CASE_DIR/triage_ledger.json'))" > /dev/null 2>&1; JSON_EXIT=$?
    python3 -c "import json,sys; d=json.load(open('$CASE_DIR/triage_ledger.json')); ok=bool(str(d.get('summary','')).strip()) and isinstance(d.get('artifacts'), list); sys.exit(0 if ok else 1)" > /dev/null 2>&1; CONTENT_EXIT=$?
    set -e

    if [ $SCHEMA_EXIT -eq 0 ] && [ $JSON_EXIT -eq 0 ] && [ $CONTENT_EXIT -eq 0 ]; then
        echo -e "${GREEN}[+] Forensic Quality Control: Schema validation passed successfully.${NC}"
        VALIDATION_PASSED=true
        break
    else
        echo -e "${YELLOW}[-] WARNING: Ledger validation failed. Initiating self-correction loop...${NC}"
        RETRY_COUNT=$((RETRY_COUNT+1))
        echo -ne "${YELLOW}[*] Retrying in: ${NC}"
	for i in $(seq "$RETRY_COOLDOWN" -1 1); do
	    echo -ne "${YELLOW}$i... ${NC}"
	    sleep 1
	done
	echo -e "${GREEN}Executing...${NC}"
    fi
done

if [ "$VALIDATION_PASSED" = false ]; then
    echo -e "${RED}[-] FATAL: AI agent failed to produce valid JSON after $MAX_RETRIES attempts. Aborting.${NC}"
    exit 1
fi
echo -ne "${CYAN}[*] Phase 1 Complete. Initiating API adaptive cooldown: ${NC}"
for i in $(seq "$PHASE_1_COOLDOWN" -1 1); do
    echo -ne "${YELLOW}$i... ${NC}"
    sleep 1
done
echo -e "${GREEN}Done!${NC}"

# ==============================================================================
# --- PHASE 2: SENIOR FORENSIC PEER REVIEW LOOP ---
# ==============================================================================
if [ "$ZERO_EVIDENCE" = true ]; then
    echo -e "${CYAN}[*] PHASE 2: Skipping Senior Peer Review due to zero-evidence protocol.${NC}"
else
    echo -e "${CYAN}[*] Initializing Phase 2: Senior Forensic Peer Review Loop...${NC}"
    touch "$CASE_DIR/critique.txt"

    # AMNESIA PROTOCOL
    cat .aider.chat.history.md >> "$CASE_DIR/agent_transcript.md" 2>/dev/null || true
    rm -f .aider.chat.history.md

    # Dynamic OS-Aware Rubric Loading
    SKILL_FLAGS=()
    if grep -qiE "windows|ntfs|registry|ntuser|exe|dll" "$EVIDENCE_FILE" 2>/dev/null; then
        SKILL_FLAGS+=(--read "reference_material/windows-artifacts/SKILL.md")
        SKILL_FLAGS+=(--read "reference_material/memory-analysis/SKILL.md")
    else
        SKILL_FLAGS+=(--read "reference_material/plaso-timeline/SKILL.md")
        SKILL_FLAGS+=(--read "reference_material/sleuthkit/SKILL.md")
    fi
    SKILL_FLAGS+=(--read "reference_material/yara-hunting/SKILL.md")

    INPUT_BYTES=$(wc -c < "$CASE_DIR/triage_ledger.json" 2>/dev/null || echo 0)
    ESTIMATED_TOKENS=$((INPUT_BYTES / 4))

    set +e
    aider --model "$AI_MODEL" \
      --map-tokens 0 \
      "${SKILL_FLAGS[@]}" \
      --message "You are a Senior Forensic Analyst conducting a quality assurance audit of a junior analyst's triage ledger.

      Read '$CASE_DIR/triage_ledger.json' and '$CASE_DIR/facts.json'. Evaluate the findings and write critique to '$CASE_DIR/critique.txt'.
      
      1. FACTUAL ACCURACY: Check for overstatement or mischaracterization of evidence.
      2. ROLE ASSIGNMENT: Did the analyst explicitly identify the Actor, Victim, and Infrastructure where supported? Flag conflated identities or forced Actor labels on shared NAT/open WiFi IPs.
      3. MITRE VALIDATION: Are the mapped MITRE TTPs explicitly proven by the artifacts? Flag unsupported mappings based on mere tool presence.
      4. SEMANTIC BIAS: Check if harassment, insider misuse, policy violations, or shared-network ambiguity were incorrectly labeled as corporate C2/malware/exfiltration.
      5. NULL HYPOTHESIS: Ensure the defense hypothesis makes sense for the specific evidence and addresses attribution/access ambiguity.
      6. IOC COMPLETENESS: Flag missing IOCs.
      Do NOT modify the JSON ledger." \
      --yes-always \
      --no-auto-commit \
      --read "$CASE_DIR/triage_ledger.json" \
      --read "$CASE_DIR/facts.json" \
      --file "$CASE_DIR/critique.txt"
    set -e

    echo "{\"timestamp\": \"$(date -u +'%Y-%m-%dT%H:%M:%SZ')\", \"action\": \"aider_pass_3_peer_review_generation\", \"estimated_input_tokens\": $ESTIMATED_TOKENS, \"status\": \"completed\"}" >> "$CASE_DIR/actions.jsonl"

    if [ -f "$CASE_DIR/critique.txt" ]; then
        echo -e "${YELLOW}[!] Critical Logic Review Generated by Peer Agent:${NC}"
        cat "$CASE_DIR/critique.txt"
        echo "────────────────────────────────────────────────────────────────────────────────"

        echo -e "${CYAN}[*] Re-engaging Agent to integrate Senior Review into Final Ledger...${NC}"
        cp "$CASE_DIR/triage_ledger.json" "$CASE_DIR/triage_ledger.json.bak"

        # AMNESIA PROTOCOL
        cat .aider.chat.history.md >> "$CASE_DIR/agent_transcript.md" 2>/dev/null || true
        rm -f .aider.chat.history.md

        INPUT_BYTES=$(wc -c < "$CASE_DIR/critique.txt" 2>/dev/null || echo 0)
        ESTIMATED_TOKENS=$((INPUT_BYTES / 4))

        aider --model "$AI_MODEL" \
          --map-tokens 0 \
          --message "Read '$CASE_DIR/critique.txt' and update '$CASE_DIR/triage_ledger.json' to address all identified issues.
          SCHEMA LOCK: Preserve the schema exactly. 
          CRITICAL FORMATTING: Output all numbers and risk scores as plain integers. No LaTeX.
          INTEGRATION: Address factual corrections, rewrite generic summaries, preserve schema exactly, correct unsupported MITRE mappings, encode supported roles in artifact name fields, avoid forced Actor labels for shared infrastructure, and ensure any named human actor is evidence-backed." \
          --yes-always --no-auto-commit \
          --read "$CASE_DIR/critique.txt" \
          --read "$CASE_DIR/facts.json" \
          --file "$CASE_DIR/triage_ledger.json"

        echo "{\"timestamp\": \"$(date -u +'%Y-%m-%dT%H:%M:%SZ')\", \"action\": \"aider_pass_4_peer_review_integration\", \"estimated_input_tokens\": $ESTIMATED_TOKENS, \"status\": \"completed\"}" >> "$CASE_DIR/actions.jsonl"

        echo -e "${CYAN}[*] Running Post-Review Schema Validation...${NC}"
        sed -i '/^
```/d' "$CASE_DIR/triage_ledger.json" || true

        if python3 verify_schema.py "$CASE_DIR/triage_ledger.json" > /dev/null 2>&1 && \
           python3 -c "import json; json.load(open('$CASE_DIR/triage_ledger.json'))" > /dev/null 2>&1; then
            echo -e "${GREEN}[+] Post-Review validation passed.${NC}"
            rm "$CASE_DIR/triage_ledger.json.bak"
        else
            echo -e "${RED}[-] 🚨 WARNING: Peer review integration broke the JSON schema! Reverting...${NC}"
            mv "$CASE_DIR/triage_ledger.json.bak" "$CASE_DIR/triage_ledger.json"
        fi
    fi

    echo "{\"timestamp\": \"$(date -u +'%Y-%m-%dT%H:%M:%SZ')\", \"actor\": \"AI_AGENT\", \"action\": \"Successfully integrated peer review feedback.\"}" >> "$CASE_DIR/actions.jsonl"
fi

# ==============================================================================
# --- PHASE 1.C: ATTACK TIMELINE RECONSTRUCTION ---
# ==============================================================================
if [ "$ZERO_EVIDENCE" = true ]; then
    echo -e "${CYAN}[*] PASS 1.C: Skipping timeline reconstruction due to zero-evidence protocol.${NC}"
else
    echo -e "${CYAN}[*] PASS 1.C: Attack Timeline Reconstruction Engine Running...${NC}"
    echo "[]" > "$CASE_DIR/timeline.json"

    # AMNESIA PROTOCOL
    cat .aider.chat.history.md >> "$CASE_DIR/agent_transcript.md" 2>/dev/null || true
    rm -f .aider.chat.history.md

    INPUT_BYTES=$(wc -c < "$CASE_DIR/facts.json" 2>/dev/null || echo 0)
    ESTIMATED_TOKENS=$((INPUT_BYTES / 4))

    set +e
    aider --model "$AI_MODEL" \
      --map-tokens 0 \
      --message "You are a strictly objective DFIR timeline analyst. Read '$CASE_DIR/facts.json' and '$CASE_DIR/triage_ledger.json'.

      Reconstruct the probable sequence of events based on artifact relationships and observed timestamps. 

      Output '$CASE_DIR/timeline.json' as a JSON array of ordered event objects.
      Each object MUST contain EXACTLY:
      'sequence' (integer starting at 1),
      'event_description' (single-line string — what happened and why it matters forensically),
      'artifacts_involved' (array of artifact name strings from facts.json),
      'mitre_ttp' (single ATT&CK technique ID if directly applicable, empty string if not),
      'confidence' (Low/Medium/High — how certain is this sequencing).

      CRITICAL FORENSIC RULES: 
      1. THREAT ACTOR ACTIVITY ONLY: The timeline must strictly contain events executed by the system or a threat actor. Never log the investigator's actions (e.g., 'Memory image captured', 'System identified', 'Hashes verified').
      2. EMPTY STATES ARE REQUIRED FOR BENIGN HOSTS: If no malicious/suspicious activity is found, leave the JSON array completely empty: []. Do not invent data.
      3. STRICT EXECUTION DEPENDENCY: If an artifact in 'triage_ledger.json' has 'execution_confidence' of 'Low' or 'None', you MUST state 'User staged/downloaded [Tool]' or 'Presence of [Tool]'. Do not state it was executed.
      4. TEMPORAL ACCURACY: If a specific date/timestamp is visible, prepend it: '[2026-06-12 14:00:00] ...'
      5. EPISTEMOLOGICAL RESTRAINT: NEVER use definitive action verbs like 'User exfiltrated'. Always use 'Evidence indicates likely data transfer via...'.
      6. RAW JSON ONLY: No markdown backticks. All strings single-line." \
      --yes-always \
      --no-auto-commit \
      --read "$CASE_DIR/facts.json" \
      --read "$CASE_DIR/triage_ledger.json" \
      --file "$CASE_DIR/timeline.json"
    set -e

    echo "{\"timestamp\": \"$(date -u +'%Y-%m-%dT%H:%M:%SZ')\", \"action\": \"aider_pass_5_timeline_reconstruction\", \"estimated_input_tokens\": $ESTIMATED_TOKENS, \"status\": \"completed\"}" >> "$CASE_DIR/actions.jsonl"

    sed -i '/^```/d' "$CASE_DIR/timeline.json" || true
    if ! python3 -c "import json; json.load(open('$CASE_DIR/timeline.json'))" > /dev/null 2>&1; then
        echo -e "${YELLOW}[-] WARNING: Timeline JSON malformed — resetting to safe fallback.${NC}"
        echo '[{"sequence": 1, "event_description": "Timeline reconstruction failed — insufficient data.", "artifacts_involved": [], "mitre_ttp": "", "confidence": "Low"}]' > "$CASE_DIR/timeline.json"
    fi

    echo "{\"timestamp\": \"$(date -u +'%Y-%m-%dT%H:%M:%SZ')\", \"actor\": \"AI_AGENT\", \"action\": \"Completed Pass 1.C: Timeline Reconstruction.\"}" >> "$CASE_DIR/actions.jsonl"
fi

# ==============================================================================
# --- PHASE 3: HUMAN EXAMINER CHECKPOINT ---
# ==============================================================================
echo ""
echo -e "${BOLD}${YELLOW}========================================================${NC}"
echo -e "${BOLD}${YELLOW}    ⚠️  CRITICAL CHECKPOINT: HUMAN EXAMINER REVIEW ⚠️${NC}"
echo -e "${BOLD}${YELLOW}========================================================${NC}"
printf "Type 'APPROVE' to authorize final report generation: "
read -r USER_INPUT

if [ "$USER_INPUT" == "APPROVE" ]; then
    sed -i 's/DRAFT_//g' "$CASE_DIR/triage_ledger.json"
    sed -i 's/PENDING_HUMAN_REVIEW/APPROVED_BY_EXAMINER/g' "$CASE_DIR/triage_ledger.json"
    
    echo -e "${CYAN}[*] Performing final renderer-safe ledger cleanup...${NC}"
    
    python3 - "$CASE_DIR/triage_ledger.json" <<'PY'
import json
import re
import sys

path = sys.argv[1]

def normalize_str(v): 
    return str(v or "").strip()

def sanitize_for_markdown_table(text, max_len=80):
    if not isinstance(text, str): return text
    clean_text = text.replace('\n', ' ').replace('\r', ' ').replace('|', '&#124;')
    if len(clean_text) > max_len:
        return clean_text[:max_len-3] + "..."
    return clean_text

def scrub(obj):
    if isinstance(obj, str):
        return re.sub(r"(?<!\\)\$([^$\n]+)(?<!\\)\$", r"\1", obj)
    if isinstance(obj, list):
        return [scrub(item) for item in obj]
    if isinstance(obj, dict):
        return {key: scrub(value) for key, value in obj.items()}
    return obj

with open(path, "r", encoding="utf-8") as handle:
    ledger = json.load(handle)

BENIGN_DOMAINS = {"gmail.com", "hotmail.com", "yahoo.com", "sbcglobal.net", 
                  "nist.gov", "outlook.com", "protonmail.com", "proton.me",
                  "google.com", "microsoft.com", "windows.com", "sourceforge.net",
                  "bing.com", "live.com", "office.com", "apple.com", "mozilla.org"}

verdict = normalize_str(ledger.get("intent_verdict")).lower()

if "mitre_ttps" in ledger and isinstance(ledger["mitre_ttps"], list):
    if verdict in ["benign", "inconclusive"] and "T1059" in ledger["mitre_ttps"]:
        ledger["mitre_ttps"].remove("T1059")

for artifact in ledger.get("artifacts", []):
    raw_risk = str(artifact.get("risk_score", "0"))
    match = re.search(r"\d+", raw_risk)
    risk_val = min(100, max(0, int(match.group()) if match else 0))
    artifact["risk_score"] = risk_val
    
    artifact["value"] = sanitize_for_markdown_table(artifact.get("value", ""), 80)
    artifact["description"] = sanitize_for_markdown_table(artifact.get("description", ""), 120)
    
    if verdict in ["benign", "inconclusive"]:
        artifact["intent_confidence"] = "Low"
        if risk_val < 20:
            artifact["priority"] = "Low"
            
    if normalize_str(artifact.get("recommended_validation")).lower() in ["none", "", "null", "pending"]:
        artifact["recommended_validation"] = "Cross-reference with workstation software deployment inventory."
    
    clean_iocs = []
    for i in artifact.get("iocs", []):
        i_str = str(i).strip()
        if i_str.lower() not in BENIGN_DOMAINS and "/" not in i_str and "\\" not in i_str:
            clean_iocs.append(i_str)
            
    blob = artifact.get("value", "") + " " + artifact.get("description", "")
    missed_hashes = re.findall(r"\b[a-fA-F0-9]{32}\b|\b[a-fA-F0-9]{40}\b|\b[a-fA-F0-9]{64}\b", blob)
    for h in missed_hashes:
        if h not in clean_iocs and risk_val >= 21:
            clean_iocs.append(h)
            
    artifact["iocs"] = clean_iocs

ledger = scrub(ledger)

with open(path, "w", encoding="utf-8") as handle:
    json.dump(ledger, handle, indent=2)
PY

    python3 generate_pdf_report.py "$CASE_DIR/triage_ledger.json"

    mkdir -p "$CASE_DIR/reports"
    mv exports/*.pdf "$CASE_DIR/reports/" 2>/dev/null || true
    cp .aider.chat.history.md "$CASE_DIR/reports/agent_transcript.md" 2>/dev/null || true
    echo -e "${GREEN}[+] PIPELINE COMPLETE. Final verified artifact saved to $CASE_DIR/reports/${NC}"
else
    echo -e "${RED}[-] Investigation Paused / AI Re-prompted based on human rejection.${NC}"
    exit 1
fi
