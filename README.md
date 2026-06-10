# Autonomous DFIR Triage Pipeline (ATP)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**Built for the SANS FIND EVIL Hackathon 2026**

The Autonomous DFIR Triage Pipeline (ATP) is an advanced, Human-in-the-Loop (HITL) agentic framework explicitly designed to extend incident response capabilities directly on the SANS SIFT Workstation. Utilizing **Aider** as the primary agentic execution engine paired with **Gemini 3.1 Flash Lite**, this platform autonomously ingests, extracts, analyzes, and stages complex forensic evidence. It strictly enforces a cryptographic human examiner checkpoint before any final reporting occurs, bridging the gap between high-speed AI analysis and legally defensible forensic rigor.

## 🏗️ Architecture Diagram

The following flowchart details the pipeline's deterministic privilege boundaries and execution pathways. By decoupling the extraction phase from the AI's cognitive phase, the architecture fundamentally prevents execution hallucinations.

```mermaid
graph TD
    A[Evidence Target] --> B{analyze.sh Orchestrator}
    B -->|.raw / .img| C[run_scan.py: Volatility 3 Extraction]
    B -->|.json| D[VIGÍA Telemetry Ingest]
    C --> E[memory_scan_results.txt]
    D --> F[telemetry_source.json]
    E --> G((Agentic Engine: Aider + Gemini))
    F --> G
    G -->|Self-Correcting Reasoning| H[triage_ledger.json DRAFT]
    G --> I[actions.jsonl Audit Log]
    H --> J{Human Examiner Checkpoint}
    J -->|Rejects| K[Investigation Paused / AI Re-prompted]
    J -->|Types APPROVE| L[Cryptographic Sign-off]
    L --> M[generate_pdf_report.py]
    M --> N[Final Verified Executive PDF Report]
✨ Key Features & Hackathon Compliance
Evidence-Agnostic Processing: Dynamically adapts to unstructured memory binaries (.raw) via Volatility 3 or structured cloud/endpoint telemetry streams (VIGÍA Canonical Format).

Defensive Specificity Calibration: Engineered with strict prompt-based guardrails to prevent False Positives. The agent is trained to recognize dual-use privacy tools (like BitLocker or GPG) and explicitly label them as SUSPICION rather than hallucinating a MALICIOUS intent without an active payload.

Human-in-the-Loop State Enforcement: The AI operates entirely in a sandboxed staging state. It cannot author formal PDF reports. All cognitive output is restricted to a DRAFT status within a JSON ledger until an authenticated human investigator reviews the findings and issues an approval command.

Append-Only Audit Trail: Every script execution, AI cognitive cycle, and human authorization is sequentially timestamped and logged in actions.jsonl to ensure unbroken chain-of-custody.

⚙️ Prerequisites & Setup Instructions
This project requires a Linux environment and was purpose-built for the SANS SIFT Workstation.

Clone the Repository:

Bash
git clone <your-repo-url>
cd <repo-folder>
2. **Install Python Dependencies:**
   Ensure you have Python 3 installed, then install the necessary reporting and agentic frameworks:
   ```bash
pip3 install weasyprint aider-chat
Configure API Authentication:
The pipeline relies the Gemini API for cognitive reasoning. Export your key to the environment:

export GEMINI_API_KEY="your-api-key"

4. **Verify Volatility 3 Integration:**
   The `run_scan.py` script requires `vol` to be executable on your system path. SIFT Workstations include this by default.

## 🚀 Usage Guide

The pipeline is initiated via a single, smart bash orchestrator. To process an evidence file, simply pass its path as an argument.

**To analyze a VIGÍA telemetry case:**
```bash
./analyze.sh vigia-intent-analysis/cases/VIGIA-REAL-005/case.json
To analyze a raw memory dump:

Bash
sudo -E ./analyze.sh /cases/Rocba-Memory/Rocba-Memory_2.raw
(Note: Use sudo -E for .raw files to grant read permissions while preserving your user environment variables for the AI).

Once initiated, the agent will extract the data, perform its analysis, stage its findings in a dedicated cases/ directory, and halt. The terminal will present a Critical Checkpoint. The human examiner must review the staged triage_ledger.json and type APPROVE in the terminal to authorize the pipeline to compile the final PDF report.
