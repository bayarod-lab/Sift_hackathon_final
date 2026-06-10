# Evidence Dataset Documentation

This pipeline was rigorously tested against three distinct data sources to prove its evidence-agnostic capabilities and cognitive reasoning. 

### 1. VIGIA-REAL-001 (NIST CFReDS - Hacking Case)
*   **Source:** Public NIST CFReDS dataset via VIGÍA Canonical Format.
*   **Data Type:** Structured JSON Telemetry (Registry, Network, Files).
*   **Agent Findings:** The agent successfully identified the threat actor's real name (Greg Schardt), hacking alias (Mr. Evil), war-driving executables (NetStumbler), and credential theft via intercepted PCAP data.
*   **Verdict:** `MALICIOUS`

### 2. VIGIA-REAL-005 (Ali Hadi - False Positive Trap)
*   **Source:** Ali Hadi challenges via VIGÍA Canonical Format.
*   **Data Type:** Structured JSON Telemetry.
*   **Agent Findings:** The agent mapped multiple layers of encryption (AES file concealment, BitLocker volume 'R2D2', and GPG/PGP keys). Crucially, the agent correctly reasoned that without an active exploit payload or exfiltration, this was privacy-focused concealment, not active malware. 
*   **Verdict:** `SUSPICION`

### 3. Rocba-Memory_2.raw (Process Injection)
*   **Source:** Hackathon standalone memory dump.
*   **Data Type:** Unstructured `.raw` binary.
*   **Agent Findings:** Processed via `run_scan.py` (Volatility 3 `windows.pstree`), the agent parsed the raw text dump and identified an anomalous circular parentage loop between `Teams.exe` instances and an execution of `smartscreen.exe` lacking an executable path.
*   **Verdict:** `MALICIOUS`
