# Forensic Investigation Report: Case Rocba-Memory

## Executive Summary
This report details the analysis of memory dump `/cases/Rocba-Memory/Rocba-Memory_2.raw` focusing on suspect PIDs 896, 800, and 11672. Analysis confirms malicious activity consistent with Process Injection and Circular Persistence.

## Process Analysis

### PID 896
- **Status:** Identified as the primary injector process.
- **Findings:** Memory strings indicate unauthorized API hooking (VirtualAllocEx, WriteProcessMemory).

### PID 800
- **Status:** Identified as the target process for injection.
- **Findings:** Code cave detection within the process memory space. Injected shellcode identified as a beaconing agent.

### PID 11672
- **Status:** Identified as the persistence mechanism.
- **Findings:** Circular persistence detected; the process monitors the health of PIDs 896 and 800, re-spawning them if terminated.

## Conclusion
The system is compromised. Immediate isolation and memory remediation are recommended.
