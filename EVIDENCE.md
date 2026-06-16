# Evidence Dataset Documentation

This pipeline was rigorously tested against diverse forensic data sources to document agent versatility, extraction capability, and cognitive reasoning constraints. The complete execution logs, agent transcripts, and final PDF reports for these specific cases are available natively in the `/cases/` directory.

### 1. ROCBA Dataset (Disk & Memory)
*   **Source of Data:** Hackathon standalone forensic dataset (`rocba-cdrive.e01` and `Rocba-Memory.zip`).
*   **What it was tested against:** Full Windows 10 logical disk image (22GB) and raw memory dump (5GB) processed via `analyze.sh`.
*   **What the Agent Found:** 
    *   **Disk:** Identified standard user workstation activity, mapping common productivity applications (Skype, Slack, iCloud) and correctly establishing a benign system baseline.
    *   **Memory:** Processed via `run_scan.py` (Volatility 3 `windows.pstree`), parsed the raw text dump, and identified anomalous circular parentage loops between `Teams.exe` instances and an execution of `smartscreen.exe` lacking an explicit executable path.
*   **Verdict:** Dynamic (`BENIGN` for Disk, `MALICIOUS` for Memory).

### 2. TDUNGAN Dataset (Compressed Telemetry)
*   **Source of Data:** Hackathon provided scenario data (`tdungan-telemetry.zip`).
*   **What it was tested against:** A compressed archive container containing decentralized workstation triage collections and triage text captures.
*   **What the Agent Found:** The orchestrator successfully executed decoupled unpacking and summary routing via `7z`. The agent mapped persistence files and staged scripts. It correctly noted the presence of administrative configuration utilities while flagging potential staging activity within standard user directories.
*   **Verdict:** `SUSPICION`

### 3. VIGIA-REAL Dataset (Case 005 - False Positive Trap)
*   **Source of Data:** Public DFIR datasets standardized via the VIGÍA Canonical Format (`Vigia_005_case.json`).
*   **What it was tested against:** Structured enterprise JSON telemetry covering layered Registry keys, Filesystem Metadata, and cryptographic configurations.
*   **What the Agent Found:** This case explicitly validated the pipeline's prompt guardrails. The agent parsed complex metadata fields and correctly reasoned that multiple layers of system-level encryption (BitLocker/GPG) without active network exploit payloads or malware execution signatures constituted baseline privacy concealment rather than an active corporate threat.
*   **Verdict:** `INCONCLUSIVE` / `BENIGN` (Successfully avoiding a false-positive `MALICIOUS` classification).
