#!/usr/bin/env python3
"""
DFIR Adaptive Universal PDF Report Generator
Dynamically maps any forensic JSON schema to a premium executive layout.
"""

import sys
import json
import datetime
from pathlib import Path

try:
    from weasyprint import HTML, CSS
    import weasyprint
except ImportError:
    raise SystemExit("weasyprint not installed. Run: pip3 install weasyprint")

CSS_STYLE = """
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;600;700&family=Roboto+Mono:wght@400;600&display=swap');

@page {
    size: A4;
    margin: 0;
    @bottom-right {
        content: "Page " counter(page) " of " counter(pages);
        font-family: 'Inter', sans-serif;
        font-size: 8pt;
        color: #9ca3af;
        margin-right: 2cm;
        margin-bottom: 0.6cm;
    }
    @bottom-left {
        content: "CONFIDENTIAL — DFIR AUTOMATED TRIAGE REPORT";
        font-family: 'Inter', sans-serif;
        font-size: 8pt;
        color: #9ca3af;
        margin-left: 2cm;
        margin-bottom: 0.6cm;
    }
}

* { box-sizing: border-box; margin: 0; padding: 0; }

body {
    font-family: 'Inter', Arial, sans-serif;
    font-size: 10pt;
    color: #1f2937;
    background: #ffffff;
    line-height: 1.6;
}

.cover {
    background: linear-gradient(135deg, #0f172a 0%, #1e3a5f 60%, #1d4ed8 100%);
    color: white;
    padding: 3cm 2.2cm 2cm 2.2cm;
    page-break-after: always;
    min-height: 100vh;
    display: flex;
    flex-direction: column;
    justify-content: space-between;
}

.org-tag { font-size: 8pt; font-weight: 600; letter-spacing: 0.18em; text-transform: uppercase; color: #93c5fd; margin-bottom: 0.5cm; }
.report-type { font-size: 10pt; color: #bfdbfe; letter-spacing: 0.05em; text-transform: uppercase; margin-bottom: 0.3cm; }
.cover h1 { font-size: 26pt; font-weight: 700; line-height: 1.2; color: #ffffff; margin-bottom: 0.4cm; }
.cover-divider { width: 60px; height: 4px; background: #3b82f6; border-radius: 2px; margin: 0.6cm 0 1cm 0; }

.cover-meta { display: table; width: 100%; margin-top: 1cm; }
.cover-meta-row { display: table-row; }
.cover-meta-label { display: table-cell; font-size: 8pt; font-weight: 600; color: #93c5fd; text-transform: uppercase; padding: 0.15cm 0.5cm 0.15cm 0; width: 4cm; }
.cover-meta-value { display: table-cell; font-size: 9.5pt; color: #e0f2fe; padding: 0.15cm 0; }

.page-header { background: #0f172a; color: white; padding: 0.4cm 2.2cm; display: flex; justify-content: space-between; font-size: 8.5pt; }
.content { padding: 1cm 2.2cm; }

h2 { font-size: 14pt; font-weight: 700; color: #0f172a; margin-top: 0.8cm; margin-bottom: 0.4cm; padding-bottom: 0.15cm; border-bottom: 2px solid #1d4ed8; }
p { margin-bottom: 0.4cm; color: #374151; }

.summary-box { background: #f0fdf4; border-left: 4px solid #16a34a; border-radius: 0 6px 6px 0; padding: 0.5cm 0.6cm; margin-bottom: 0.6cm; }

table { width: 100%; border-collapse: collapse; margin: 0.5cm 0; font-size: 9pt; }
thead tr { background: #1e3a5f; color: white; }
thead th { padding: 0.25cm 0.3cm; text-align: left; font-weight: 600; text-transform: uppercase; font-size: 8pt; letter-spacing: 0.05em; }
tbody tr:nth-child(even) { background: #f8fafc; }
tbody td { padding: 0.25cm 0.3cm; border-bottom: 1px solid #e5e7eb; vertical-align: top; }

code { font-family: 'Roboto Mono', monospace; font-size: 8.5pt; background: #f1f5f9; padding: 0.05cm 0.15cm; border-radius: 3px; color: #0f172a; }
.footer-note { margin-top: 1cm; padding-top: 0.4cm; border-top: 1px solid #e5e7eb; font-size: 8pt; color: #9ca3af; }
"""

def parse_evidence_json(data: dict) -> dict:
    """Intelligently extracts core fields regardless of schema variations."""
    parsed = {
        "case_id": data.get("case_id") or data.get("id") or "VIGIA-GENERIC",
        "target": data.get("target_file") or data.get("evidence_name") or data.get("target") or "Forensic Context Capture",
        "verdict": data.get("intent_verdict") or data.get("verdict") or "SUSPICION",
        "description": data.get("summary") or data.get("description") or data.get("incident_descriptor") or "No explicit case abstract description found within data profile structure.",
        "artifacts": []
    }

    # Normalize descriptions if nested in an incident descriptor object
    if isinstance(parsed["description"], dict):
        parsed["description"] = parsed["description"].get("details") or str(parsed["description"])

    # Search dynamically for arrays of indicators, findings, or artifacts
    for key in ["indicators", "findings", "artifacts", "evidence", "cases"]:
        if key in data and isinstance(data[key], list):
            parsed["artifacts"] = data[key]
            break
            
    # If no array found, convert root key-value anomalies into entries
    if not parsed["artifacts"]:
        for k, v in data.items():
            if k not in ["case_id", "id", "target_file", "evidence_name", "target", "intent_verdict", "verdict", "summary", "description", "incident_descriptor"]:
                parsed["artifacts"].append({"type": str(k), "description": str(v)})

    return parsed

def generate_html(parsed: dict) -> str:
    date_str = datetime.datetime.utcnow().strftime("%Y-%m-%d")
    
    # Build dynamic table body rows
    rows_html = ""
    for idx, item in enumerate(parsed["artifacts"]):
        if isinstance(item, dict):
            type_str = item.get("type") or item.get("name") or f"Artifact element {idx+1}"
            desc_str = item.get("description") or item.get("details") or item.get("value") or json.dumps(item)
            context_str = item.get("pid") or item.get("context") or item.get("severity") or "N/A"
        else:
            type_str = "Evidence Log Entry"
            desc_str = str(item)
            context_str = "N/A"
            
        rows_html += f"""
        <tr>
            <td><strong>{type_str}</strong></td>
            <td><code>{context_str}</code></td>
            <td>{desc_str}</td>
        </tr>"""

    return f"""<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8"/>
    <style>{CSS_STYLE}</style>
</head>
<body>

<div class="cover">
  <div class="cover-top">
    <div class="org-tag">Digital Forensics &amp; Incident Response</div>
    <div class="report-type">Dynamic Triage Assessment</div>
    <h1>Forensic Triage Deliverable</h1>
    <div class="cover-divider"></div>
    <div class="cover-meta">
      <div class="cover-meta-row"><div class="cover-meta-label">Case Reference</div><div class="cover-meta-value">{parsed['case_id']}</div></div>
      <div class="cover-meta-row"><div class="cover-meta-label">Evidence Path</div><div class="cover-meta-value"><code>{parsed['target']}</code></div></div>
      <div class="cover-meta-row"><div class="cover-meta-label">Intent Valuation</div><div class="cover-meta-value" style="font-weight:700; color:#fbbf24;">{parsed['verdict']}</div></div>
      <div class="cover-meta-row"><div class="cover-meta-label">Compiler Date</div><div class="cover-meta-value">{date_str} UTC</div></div>
    </div>
  </div>
  <div class="cover-bottom">
    <div class="cover-classification">&#9632; CONFIDENTIAL — HIGHLY RESTRICTED</div>
    <div class="cover-date">System Time: {date_str}</div>
  </div>
</div>

<div class="page-header">
  <div>Incident Analysis Execution Report</div>
  <div>Ref: {parsed['case_id']}</div>
</div>

<div class="content">
  <h2><span class="section-num">01</span> Case Abstract &amp; Context</h2>
  <div class="summary-box">
    <p>{parsed['description']}</p>
  </div>

  <h2><span class="section-num">02</span> Extracted Structural Artifacts Matrix</h2>
  <table>
    <thead>
      <tr>
        <th style="width: 25%;">Classification Element</th>
        <th style="width: 20%;">Identifier Context</th>
        <th style="width: 55%;">Technical Log Observations / Metadata</th>
      </tr>
    </thead>
    <tbody>
        {rows_html}
    </tbody>
  </table>

  <div class="footer-note">
    This artifact was compiled programmatically via an isolated automated forensic reporting pipeline. 
    Source layout metrics map securely to original underlying JSON descriptors.
  </div>
</div>

</body>
</html>"""

def compile_report(json_path: str, output_path: str = "./exports/Dynamic_Executive_Report.pdf"):
    p = Path(json_path)
    if not p.exists():
        print(f"Error: Target path {json_path} does not exist.")
        return

    with open(p, "r") as f:
        raw_data = json.load(f)

    parsed_data = parse_evidence_json(raw_data)
    html_content = generate_html(parsed_data)
    
    out_p = Path(output_path)
    out_p.parent.mkdir(parents=True, exist_ok=True)
    
    HTML(string=html_content).write_pdf(str(out_p))
    print(f"[+] Success! Dynamic premium report compiled at: {out_p.resolve()}")

if __name__ == "__main__":
    target = "./vigia-intent-analysis/cases/VIGIA-REAL-005/case.json"
    if len(sys.argv) > 1:
        target = sys.argv[1]
        
    compile_report(target)
