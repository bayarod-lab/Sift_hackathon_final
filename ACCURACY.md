# Accuracy Report & Self-Assessment

In accordance with Hackathon rules, this is an honest self-assessment of the agent's accuracy, detailing the false positives, missed artifacts, and hallucinated claims identified during testing, alongside subsequent architectural corrections. Honesty is valued over perfection.

### 1. Hallucinated Claims: The "Execution Pipe" Bypass
*   **Issue:** Early iterations of the agent lacked direct access to an MCP server. When instructed to scan memory, it hallucinated terminal commands (e.g., `echo {...} | mcp`) to attempt execution.
*   **Correction:** We decoupled execution from the LLM. We built `analyze.sh` to deterministically extract the evidence first via native binaries, then hand the read-only text to the agent. This entirely eliminated execution hallucinations.

### 2. False Positives: The Encryption Trap (VIGIA-REAL-005)
*   **Issue:** During baseline testing against VIGIA-REAL-005, the agent incorrectly flagged the case as `MALICIOUS` because it equated BitLocker and GPG keys with threat actor evasion.
*   **Correction:** We applied strict forensic calibration to the agent's prompt. We engineered a rule dictating that encryption layers without explicit malware payloads must be classified as `SUSPICION` or `INCONCLUSIVE`. The agent now successfully differentiates between legitimate privacy practices and hostile intent.

### 3. Hallucinated Claims: Schema Drift via Model Upgrades
*   **Issue:** Upgrading to the latest `gemini-3.5-flash` model for rate-limit and speed improvements caused the agent to occasionally hallucinate nested JSON keys, breaking the downstream WeasyPrint PDF reporting tool.
*   **Correction:** We implemented a strict JSON schema template directly inside the bash prompt injection and a programmatic Python post-triage validation module (`run_validation.py`) to automatically detect and repair broken structures before compiling reports.

### 4. Missed Artifacts & Known Limitations
While highly accurate at identifying anomalous process trees and documented IOCs, the agent currently relies on the depth of the initial automated extraction layers. 
*   **Concrete Documented Instance (False Negative):** During testing on the `tdungan-telemetry.zip` collection, the agent failed to flag a secondary suspicious obfuscated payload entry deep within a packed data subfolder. Ground-truth review confirmed the entry was present, but because our extraction script aggressively applies token-limit line truncation to avoid context window blowouts, the payload data fell below the threshold window and was never fed to the AI.

### 5. Architectural Enforcement vs. Prompt Adherence (Addressing IDE Read-Only Limitations)
In accordance with Category 4 Hackathon requirements regarding Alternative Agentic IDEs (Aider), this section documents system behavior when the LLM attempts to violate read-only evidence constraints.

Because Aider relies heavily on prompt adherence, a hallucinating model might attempt to rewrite the source evidence instead of the ledger. Our pipeline mitigates this through a dual-layer failure state:
*   **The Application Layer (Aider `--read` flag):** The orchestrator injects the source evidence into Aider's context window explicitly as a read-only file. If the LLM generates a unified diff attempting to alter the evidence, Aider's core logic automatically rejects the edit block.
*   **The Logged Failure Chain Excerpt:** If the model ignores restrictions and attempts a destructive edit, our automated post-processing validation loop catches the error, blocks the commit, and triggers a self-correction REPL loop. Below is a validated trace excerpt from `actions.jsonl` confirming this defensive behavior:
```json
    {"timestamp": "2026-06-15T18:42:10Z", "action": "aider_diff_rejected", "reason": "Attempted to modify read-only evidence file 'telemetry_source.json'"}
    {"timestamp": "2026-06-15T18:42:12Z", "actor": "SYSTEM", "action": "Validation failed: triage_ledger.json not updated. Triggering Phase 2 self-correction loop."}
```
*   **The Result:** The chain of custody for the underlying evidence files remains mathematically unbroken.
