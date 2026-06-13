#!/usr/bin/env python3
"""
DFIR Executive PDF Report Generator (Dynamic Version)
Uses WeasyPrint to render styled HTML → PDF.
Accepts a JSON file as an argument to dynamically build reports for any case.
"""

import sys
import json
import re
from pathlib import Path
from datetime import datetime, timezone

try:
    from weasyprint import HTML, CSS
except ImportError:
    raise SystemExit("weasyprint not installed. Run: pip3 install weasyprint")


# ── Brand / Style ─────────────────────────────────────────────────────────────

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
        content: "CONFIDENTIAL — DFIR INTERNAL USE ONLY";
        font-family: 'Inter', sans-serif;
        font-size: 8pt;
        color: #9ca3af;
        margin-left: 2cm;
        margin-bottom: 0.6cm;
    }
}

* { box-sizing: border-box; margin: 0; padding: 0; }

body {
    font-family: 'Inter', 'Helvetica Neue', Arial, sans-serif;
    font-size: 9.5pt;
    color: #1f2937;
    background: #ffffff;
    line-height: 1.55;
}

/* ── Cover / Header ── */
.cover {
    background: linear-gradient(135deg, #0f172a 0%, #1e3a5f 60%, #1d4ed8 100%);
    color: white;
    padding: 2.8cm 2.2cm 2cm 2.2cm;
    page-break-after: always;
    min-height: 100vh;
    display: flex;
    flex-direction: column;
    justify-content: space-between;
}

.cover-top { }

.org-tag {
    font-size: 8pt;
    font-weight: 600;
    letter-spacing: 0.18em;
    text-transform: uppercase;
    color: #93c5fd;
    margin-bottom: 0.5cm;
}

.report-type {
    font-size: 10pt;
    font-weight: 400;
    color: #bfdbfe;
    letter-spacing: 0.05em;
    text-transform: uppercase;
    margin-bottom: 0.3cm;
}

.cover h1 {
    font-size: 28pt;
    font-weight: 700;
    line-height: 1.15;
    color: #ffffff;
    margin-bottom: 0.4cm;
}

.cover-subtitle {
    font-size: 13pt;
    font-weight: 300;
    color: #bfdbfe;
    margin-bottom: 1cm;
}

.cover-divider {
    width: 60px;
    height: 4px;
    background: #3b82f6;
    border-radius: 2px;
    margin: 0.6cm 0 1cm 0;
}

.cover-meta {
    display: table;
    border-collapse: collapse;
    width: 100%;
    margin-top: 0.6cm;
}
.cover-meta-row { display: table-row; }
.cover-meta-label {
    display: table-cell;
    font-size: 8pt;
    font-weight: 600;
    color: #93c5fd;
    text-transform: uppercase;
    letter-spacing: 0.08em;
    padding: 0.12cm 0.6cm 0.12cm 0;
    white-space: nowrap;
    width: 3cm;
}
.cover-meta-value {
    display: table-cell;
    font-size: 9pt;
    color: #e0f2fe;
    padding: 0.12cm 0;
}

.cover-bottom {
    border-top: 1px solid rgba(255,255,255,0.15);
    padding-top: 0.4cm;
    display: flex;
    justify-content: space-between;
    align-items: flex-end;
}
.cover-classification {
    font-size: 8pt;
    font-weight: 700;
    letter-spacing: 0.15em;
    color: #fbbf24;
    text-transform: uppercase;
}
.cover-date {
    font-size: 8pt;
    color: #93c5fd;
}

/* ── Page header stripe ── */
.page-header {
    background: #0f172a;
    color: white;
    padding: 0.35cm 2.2cm;
    display: flex;
    justify-content: space-between;
    align-items: center;
}
.page-header-title {
    font-size: 8.5pt;
    font-weight: 600;
    letter-spacing: 0.05em;
    color: #93c5fd;
}
.page-header-case {
    font-size: 8pt;
    color: #6b7280;
}

/* ── Content area ── */
.content {
    padding: 0.8cm 2.2cm 1.5cm 2.2cm;
}

/* ── Section headings ── */
h2 {
    font-size: 14pt;
    font-weight: 700;
    color: #0f172a;
    margin-top: 0.8cm;
    margin-bottom: 0.3cm;
    padding-bottom: 0.15cm;
    border-bottom: 2.5px solid #1d4ed8;
    display: flex;
    align-items: center;
    gap: 0.3cm;
}
h2 .section-num {
    background: #1d4ed8;
    color: white;
    font-size: 9pt;
    font-weight: 700;
    padding: 0.05cm 0.22cm;
    border-radius: 3px;
    min-width: 0.7cm;
    text-align: center;
}

/* ── Executive Summary box ── */
.exec-summary {
    background: #eff6ff;
    border-left: 4px solid #1d4ed8;
    border-radius: 0 6px 6px 0;
    padding: 0.4cm 0.6cm;
    margin: 0.3cm 0 0.5cm 0;
}
.exec-summary p { margin-bottom: 0.15cm; font-size: 9.5pt; }

.coverage-box {
    background: #f8fafc;
    border: 1px solid #e2e8f0;
    padding: 10px;
    margin-top: 10px;
    margin-bottom: 5px;
    border-radius: 4px;
}
.cov-title {
    font-size: 8.5pt;
    font-weight: 700;
    color: #334155;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    margin-bottom: 5px;
    display: block;
}
.cov-badge {
    display: inline-block;
    margin-right: 8px;
    margin-top: 4px;
    padding: 3px 6px;
    border-radius: 3px;
    font-size: 7.5pt;
    border: 1px solid #ccc;
}
.cov-yes { background: #dcfce7; color: #166534; border-color: #86efac; }
.cov-no { background: #fee2e2; color: #991b1b; border-color: #fca5a5; }

/* ── Tables ── */
table {
    width: 100%;
    border-collapse: collapse;
    margin: 0.25cm 0 0.5cm 0;
    font-size: 8.5pt;
    table-layout: fixed;
}
thead tr { background: #1e3a5f; color: white; }
thead th {
    padding: 0.18cm 0.28cm;
    text-align: left;
    font-weight: 600;
    font-size: 8pt;
    letter-spacing: 0.04em;
    text-transform: uppercase;
}
/* CRITICAL FIX: Forces rows to stay bound to a single page context */
tbody tr { 
    page-break-inside: avoid !important; 
}
tbody tr:nth-child(even) { background: #f8fafc; }
tbody tr:nth-child(odd)  { background: #ffffff; }
tbody td {
    padding: 0.15cm 0.28cm;
    border-bottom: 1px solid #e5e7eb;
    vertical-align: top;
    word-wrap: break-word;
}

/* ── Badges & Tags ── */
code {
    font-family: 'Roboto Mono', 'Courier New', monospace;
    font-size: 8pt;
    background: #f1f5f9;
    padding: 0.02cm 0.1cm;
    border-radius: 3px;
    color: #0f172a;
    word-break: break-all;
}

.badge { display: inline-block; padding: 2px 6px; border-radius: 3px; font-size: 7.5pt; font-weight: 600; text-transform: uppercase; }
.badge-high { background: #fee2e2; color: #991b1b; }
.badge-medium { background: #ffedd5; color: #9a3412; }
.badge-low { background: #f1f5f9; color: #475569; }
.badge-info { background: #e0f2fe; color: #075985; }

.risk-badge { display: inline-block; margin-bottom: 4px; padding: 2px 6px; border-radius: 3px; font-size: 7.5pt; font-weight: bold; }
.risk-high { background: #fef2f2; color: #b91c1c; border: 1px solid #f87171; }
.risk-medium { background: #fffbeb; color: #b45309; border: 1px solid #fbbf24; }
.risk-low { background: #f8fafc; color: #334155; border: 1px solid #cbd5e1; }

.pri-badge { display: block; width: fit-content; padding: 2px 6px; border-radius: 3px; font-size: 7.5pt; font-weight: bold; text-transform: uppercase; }
.pri-high { background: #dc2626; color: white; }
.pri-medium { background: #f59e0b; color: white; }
.pri-low { background: #64748b; color: white; }

/* ── Metric cards ── */
.metric-row { display: flex; gap: 0.3cm; margin: 0.3cm 0; }
.metric-card {
    flex: 1;
    background: #f8fafc;
    border: 1px solid #e2e8f0;
    border-top: 3px solid #1d4ed8;
    border-radius: 5px;
    padding: 0.3cm 0.4cm;
    text-align: center;
}
.metric-card.red-top  { border-top-color: #dc2626; }
.metric-card.orange-top { border-top-color: #f97316; }
.metric-card.green-top  { border-top-color: #16a34a; }
.metric-number { font-size: 16pt; font-weight: 700; color: #0f172a; line-height: 1.1; }
.metric-label { font-size: 7.5pt; font-weight: 600; color: #6b7280; text-transform: uppercase; letter-spacing: 0.07em; margin-top: 0.05cm; }

.footer-note {
    margin-top: 0.8cm;
    padding-top: 0.3cm;
    border-top: 1px solid #e5e7eb;
    font-size: 7.5pt;
    color: #9ca3af;
}
"""

def build_html(data: dict) -> str:
    case_id    = data.get("case_id", "UNKNOWN-CASE")
    client     = data.get("client", "Automated Triage Pipeline")
    prepared   = data.get("prepared_by", "Autonomous DFIR Agent")
    date_str   = data.get("date", datetime.now().strftime("%Y-%m-%d"))
    title      = data.get("title", "Dynamic Triage Assessment")
    subtitle   = data.get("subtitle", "Autonomous Forensic Report")
    body_html  = data.get("body_html", "")

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"/>
<style>{CSS_STYLE}</style>
</head>
<body>

<!-- ══ COVER PAGE ══ -->
<div class="cover">
  <div class="cover-top">
    <div class="org-tag">Digital Forensics &amp; Incident Response</div>
    <div class="report-type">Confidential Forensic Analysis</div>
    <h1>{title}</h1>
    <div class="cover-subtitle">{subtitle}</div>
    <div class="cover-divider"></div>
    <div class="cover-meta">
      <div class="cover-meta-row">
        <div class="cover-meta-label">Pipeline</div>
        <div class="cover-meta-value">{client}</div>
      </div>
      <div class="cover-meta-row">
        <div class="cover-meta-label">Case ID</div>
        <div class="cover-meta-value">{case_id}</div>
      </div>
      <div class="cover-meta-row">
        <div class="cover-meta-label">Prepared By</div>
        <div class="cover-meta-value">{prepared}</div>
      </div>
      <div class="cover-meta-row">
        <div class="cover-meta-label">Report Date</div>
        <div class="cover-meta-value">{date_str} UTC</div>
      </div>
    </div>
  </div>
  <div class="cover-bottom">
    <div class="cover-classification">&#9632; Confidential</div>
    <div class="cover-date">Report generated {date_str}</div>
  </div>
</div>

<!-- ══ BODY PAGES ══ -->
<div class="page-header">
  <div class="page-header-title">{title}</div>
  <div class="page-header-case">Case: {case_id}</div>
</div>
<div class="content">
{body_html}
<div class="footer-note">
  This report was produced automatically via an LLM-driven forensic pipeline.
  Findings are based strictly on evidence present in the provided target at the time of analysis.
</div>
</div>

</body>
</html>"""

def extract_coverage(summary_text: str) -> tuple:
    """Parses the 'Coverage: Filesystem=YES...' string out of the summary."""
    coverage_html = ""
    match = re.search(r'(Coverage:\s*.*?)(?:$|\n)', summary_text)
    if match:
        cov_str = match.group(1)
        # Remove from main summary
        summary_text = summary_text.replace(cov_str, '').strip()
        
        # Parse items
        items = cov_str.replace("Coverage:", "").split(";")
        badges = ""
        for item in items:
            if "=" in item:
                k, v = item.split("=", 1)
                k = k.strip()
                v = v.strip().upper()
                css_cls = "cov-yes" if "YES" in v else "cov-no"
                badges += f'<span class="cov-badge {css_cls}"><b>{k}</b>: {v}</span>'
        
        if badges:
            coverage_html = f'<div class="coverage-box"><span class="cov-title">Evidence Coverage Matrix</span>{badges}</div>'
            
    return summary_text, coverage_html

def build_dynamic_body(json_data: dict, real_target_path: str) -> str:
    verdict = json_data.get("intent_verdict", "UNKNOWN").upper()
    summary = json_data.get("summary", "No summary provided by the agent.")
    artifacts = json_data.get("artifacts", [])

    # --- Extract MITRE TTPs ---
    mitre_ttps = json_data.get("mitre_ttps", [])
    mitre_html = ""
    if mitre_ttps:
        mitre_html = f'<div style="margin-bottom: 15px; font-size: 8.5pt; color: #334155;"><b>Identified MITRE ATT&CK Techniques:</b> <code>{", ".join(mitre_ttps)}</code></div>'

    # Extract coverage matrix visually
    summary, coverage_html = extract_coverage(summary)

    # Set styles based on AI verdict
    verdict_color_class = "green-top"
    if verdict == "MALICIOUS" or verdict == "CONFIRMED MALICIOUS":
        verdict_color_class = "red-top"
    elif verdict == "SUSPICIOUS":
        verdict_color_class = "orange-top"

    # Build the Artifacts Table dynamically with strict column matching (5 columns total)
    if len(artifacts) > 0:
        artifacts_rows = ""
        for art in artifacts:
            # Strip hidden newlines to prevent PDF table wrapping errors
            name = str(art.get("name", "Unknown Artifact")).replace("\n", " ").replace("\r", " ").strip()
            desc = str(art.get("description", "No description provided.")).replace("\n", " ").replace("\r", " ").strip()
            
            # --- RENDER EXPLICIT IOC BLOCK ---
            iocs = art.get("iocs", [])
            if iocs and isinstance(iocs, list):
                # Clean out any empty strings
                valid_iocs = [i.strip() for i in iocs if i.strip()]
                if valid_iocs:
                    ioc_str = "<br>".join(valid_iocs)
                    # Append a red, monospaced alert box directly into the description column
                    desc += f'<div style="margin-top: 8px; padding: 6px; background: #fee2e2; border-left: 3px solid #ef4444; border-radius: 3px; font-family: monospace; font-size: 7.5pt; word-wrap: break-word; color: #7f1d1d;"><b>INDICATORS OF COMPROMISE:</b><br>{ioc_str}</div>'
            rec_val = str(art.get("recommended_validation", "Manual review required.")).replace("\n", " ").replace("\r", " ").strip()
            
            # DEFENSIVE PROGRAMMING FALLBACK: Support both 'confidence' and 'confidence_level'
            conf = str(art.get("confidence", art.get("confidence_level", "Low"))).strip().title()
            
            # --- Extract Risk Score safely ---
            risk_val = art.get("risk_score", 0)
            try: 
                risk_val = int(risk_val)
            except (ValueError, TypeError): 
                risk_val = 0
            
            risk_html = str(risk_val) + "/100"
            # SANITY SCRUBBER: Strip out any accidental LaTeX math markers ($) injected by the model
            risk_html = risk_html.replace("$", "")
            
            pri_val = art.get("priority", "Low").title()
            
            # Render Risk Badge
            risk_cls = "risk-low"
            if risk_val >= 75: risk_cls = "risk-high"
            elif risk_val >= 40: risk_cls = "risk-medium"
            
            # Render Priority Badge
            pri_cls = "pri-low"
            if pri_val == "High": pri_cls = "pri-high"
            elif pri_val == "Medium": pri_cls = "pri-medium"
            
            risk_html = f'<div class="risk-badge {risk_cls}">Risk: {risk_val}/100</div><div class="pri-badge {pri_cls}">{pri_val} Priority</div>'

            # Render Confidence Badge
            conf_badge = f'<span class="badge badge-info">{conf}</span>'
            if conf.upper() == "HIGH":
                conf_badge = f'<span class="badge badge-high">{conf}</span>'
            elif conf.upper() == "MEDIUM":
                conf_badge = f'<span class="badge badge-medium">{conf}</span>'
            elif conf.upper() == "LOW":
                conf_badge = f'<span class="badge badge-low">{conf}</span>'

            artifacts_rows += f"<tr><td><code>{name}</code></td><td>{desc}</td><td>{risk_html}</td><td>{conf_badge}</td><td>{rec_val}</td></tr>"
        
        artifacts_table = f"""
        <table>
          <thead><tr>
            <th style="width: 20%;">Artifact / Finding</th>
            <th style="width: 35%;">Forensic Observation</th>
            <th style="width: 15%;">Risk &amp; Priority</th>
            <th style="width: 12%;">Confidence</th>
            <th style="width: 18%;">Recommended Validation</th>
          </tr></thead>
          <tbody>
            {artifacts_rows}
          </tbody>
        </table>
        """
    else:
        artifacts_table = "<p><em>No specific malicious or suspicious artifacts were extracted by the agent during this scan.</em></p>"

    html = f"""
    <h2><span class="section-num">01</span> Executive Summary</h2>
    <div class="exec-summary">
      <p>{summary}</p>
    </div>
    {coverage_html}
    {mitre_html}

    <div class="metric-row">
      <div class="metric-card {verdict_color_class}">
        <div class="metric-number">{verdict}</div>
        <div class="metric-label">Assessed Intent Verdict</div>
      </div>
      <div class="metric-card">
        <div class="metric-number">{len(artifacts)}</div>
        <div class="metric-label">Extracted Findings</div>
      </div>
    </div>

    <h2><span class="section-num">02</span> System Profile &amp; Evidence Scope</h2>
    <table>
      <thead><tr><th style="width: 25%;">Property</th><th>Value</th></tr></thead>
      <tbody>
        <tr><td>Target Evidence Path</td><td><code>{real_target_path}</code></td></tr>
        <tr><td>Analysis Timestamp</td><td>{datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")}</td></tr>
        <tr><td>Analysis Tooling</td><td>Autonomous MCP Framework</td></tr>
      </tbody>
    </table>

    <h2><span class="section-num">03</span> Extracted Findings Matrix</h2>
    {artifacts_table}
    """
    
    return html


def generate_report(data: dict, output_path: str, real_target_path: str) -> str:
    html = build_html(data)
    HTML(string=html).write_pdf(
        output_path,
        stylesheets=[CSS(string="")],
        presentational_hints=True,
    )
    return output_path


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Error: You must provide a JSON file.")
        print("Usage: python3 generate_pdf_report.py triage_report.json")
        sys.exit(1)

    json_filepath = sys.argv[1]

    try:
        with open(json_filepath, 'r') as f:
            triage_data = json.load(f)
    except Exception as e:
        print(f"Error reading JSON file {json_filepath}: {e}")
        sys.exit(1)

    # Pull the real target path from the chain_of_custody log to fix "Target: Unknown"
    case_dir = Path(json_filepath).parent
    coc_path = case_dir / "chain_of_custody.txt"
    real_target = triage_data.get("target", "Unknown")
    
    if coc_path.exists():
        try:
            for line in coc_path.read_text().splitlines():
                if line.startswith("Source File:"):
                    real_target = line.split("Source File:", 1)[1].strip()
                    break
        except Exception:
            pass

    current_date = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    case_id = triage_data.get("case_id", "UNKNOWN-CASE")
    
    report_data = {
        "case_id": case_id,
        "date": current_date,
        "title": "Dynamic Triage Assessment",
        "subtitle": "Autonomous Forensic Report",
        "body_html": build_dynamic_body(triage_data, real_target),
    }

    exports_dir = Path("./exports/")
    exports_dir.mkdir(parents=True, exist_ok=True)
    output_pdf_path = exports_dir / f"Dynamic_Report_{case_id}.pdf"

    generate_report(report_data, str(output_pdf_path), real_target)
    print(f"[+] PDF incident report generated successfully: {output_pdf_path}")
