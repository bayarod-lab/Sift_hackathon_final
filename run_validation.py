import json
import re
import sys

BENIGN_DOMAINS = {"gmail.com", "hotmail.com", "yahoo.com", "sbcglobal.net", 
                  "nist.gov", "outlook.com", "protonmail.com", "proton.me",
                  "google.com", "microsoft.com", "windows.com", "sourceforge.net",
                  "bing.com", "live.com", "office.com", "apple.com", "mozilla.org"}

facts_path, ledger_path = sys.argv[1], sys.argv[2]
with open(facts_path, "r", encoding="utf-8") as f: facts = json.load(f)
with open(ledger_path, "r", encoding="utf-8") as f: ledger = json.load(f)

artifacts = ledger.get("artifacts", [])
if not isinstance(artifacts, list): artifacts = []

def normalize_str(v): return str(v or "").strip()

def add_artifact_if_missing(name, a_type, value, ioc_value, presence="High", exec_conf="None", intent="None", risk_score=60, priority="Medium", description="Recovered IOC."):
    value_s = normalize_str(value)
    if not value_s: return
    low = value_s.lower()
    for art in artifacts:
        if normalize_str(art.get("value")).lower() == low:
            iocs = art.get("iocs", [])
            if not isinstance(iocs, list): iocs = []
            if ioc_value and ioc_value not in iocs:
                iocs.append(ioc_value)
                art["iocs"] = iocs
            return
    artifacts.append({
        "name": name, "type": a_type, "value": value_s, "description": description,
        "presence_confidence": presence, "execution_confidence": exec_conf, "intent_confidence": intent, 
        "recommended_validation": "Corroborate telemetry.",
        "risk_score": int(risk_score), "priority": priority, "review_status": "pending",
        "iocs": [ioc_value] if ioc_value else [],
    })

fact_iocs = []
actor_name, incident_type, case_desc = "", "", ""

for fact in facts:
    a_name, a_type, a_value = normalize_str(fact.get("artifact_name")), normalize_str(fact.get("artifact_type")), normalize_str(fact.get("artifact_value"))
    if a_name == "Incident Type": incident_type = a_value
    if a_name == "Case Description": case_desc = a_value
    if a_name == "Attributed Human Actor": actor_name = a_value

    iocs = fact.get("iocs", [])
    if isinstance(iocs, list):
        for i in iocs:
            if normalize_str(i): fact_iocs.append((a_name, a_type, a_value, normalize_str(i)))

existing_iocs = {normalize_str(i).lower() for art in artifacts for i in art.get("iocs", []) if normalize_str(i)}

verdict_check = normalize_str(ledger.get("intent_verdict")).lower()

if verdict_check not in ["benign", "inconclusive"]:
    for a_name, a_type, a_value, ioc in fact_iocs:
        if ioc.lower() in existing_iocs: continue
        low = a_name.lower()
        if "ip" in low:
            pri = "High" if "internal" in low else "Medium"
            add_artifact_if_missing(a_name or "IP Address", "network_flow", ioc, ioc, risk_score=50, priority=pri)
        elif "email" in low:
            add_artifact_if_missing(a_name or "Observed Email", "email_header", ioc, ioc, risk_score=40, priority="Medium")
        elif a_name == "Domain":
            if ioc.lower() not in BENIGN_DOMAINS:
                add_artifact_if_missing("Domain", "network_flow", ioc, ioc, risk_score=50, priority="Medium")
        else:
            add_artifact_if_missing(a_name or "Recovered Artifact", a_type or "observed", a_value or ioc, ioc, risk_score=30, priority="Low", description="Administrative/Baseline artifact recovered from telemetry.")
        existing_iocs.add(ioc.lower())

for fact in facts:
    if fact.get("artifact_name") == "Hostname":
        true_hostname = fact.get("artifact_value")
        if true_hostname:
            for art in artifacts:
                if art.get("name") == "Hostname":
                    art["value"] = true_hostname
                    if true_hostname not in art.get("iocs", []):
                        art["iocs"].append(true_hostname)

verdict = normalize_str(ledger.get("intent_verdict")).lower()

if "mitre_ttps" in ledger and isinstance(ledger["mitre_ttps"], list):
    if verdict in ["benign", "inconclusive"] and "T1059" in ledger["mitre_ttps"]:
        ledger["mitre_ttps"].remove("T1059")

for art in artifacts:
    art_val_lower = normalize_str(art.get("value")).lower()
    art_name_lower = normalize_str(art.get("name")).lower()
    art_desc_lower = normalize_str(art.get("description")).lower()
    
    if normalize_str(art.get("recommended_validation")).lower() in ["none", "", "null", "pending"]:
        art["recommended_validation"] = "Cross-reference with workstation software deployment inventory."

    if verdict in ["benign", "inconclusive"]:
        if art.get("intent_confidence") == "High":
            art["intent_confidence"] = "Low"
        if art.get("priority") == "High" and art["risk_score"] < 20:
            art["priority"] = "Low"
            
    if "no evidence of service account" in art_desc_lower or verdict == "benign":
        if "service" in art_name_lower:
            art["name"] = "User Account Workspace Profile"

summary = normalize_str(ledger.get("summary"))
if actor_name and actor_name.lower() not in summary.lower():
    summary = f"Attributed human actor identified: {actor_name}. " + summary

target = normalize_str(ledger.get("target"))
if (not target) or target.lower() == "unknown":
    m = re.search(r"professor\s+([A-Z][a-z]+\s+[A-Z][a-z]+)", case_desc)
    if m: target = m.group(1)

mitre_set = set(ledger.get("mitre_ttps", []))
case_confidence = int(ledger.get("case_confidence", 0) or 0)

for art in artifacts:
    raw_risk = str(art.get("risk_score", "0"))
    match = re.search(r"\d+", raw_risk)
    risk_val = int(match.group()) if match else 0
    art["risk_score"] = min(100, max(0, risk_val))
    
    art["iocs"] = [i for i in art.get("iocs", []) if i.lower() not in BENIGN_DOMAINS]
    if art["risk_score"] < 20:
        art["iocs"] = []

ledger["summary"] = summary
ledger["target"] = target or ledger.get("target", "Unknown")
ledger["mitre_ttps"] = sorted(mitre_set)
ledger["case_confidence"] = case_confidence
ledger["artifacts"] = artifacts

def scrub_latex(obj):
    if isinstance(obj, str): return re.sub(r"(?<!\\)\$([^$\n]+)(?<!\\)\$", r"\1", obj)
    if isinstance(obj, list): return [scrub_latex(item) for item in obj]
    if isinstance(obj, dict): return {key: scrub_latex(value) for key, value in obj.items()}
    return obj

ledger = scrub_latex(ledger)

with open(ledger_path, "w", encoding="utf-8") as f: json.dump(ledger, f, indent=2)
