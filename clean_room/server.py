from mcp.server.fastmcp import FastMCP
import forensic_tools

# Initialize your server
mcp = FastMCP("Protocol SIFT Autonomous Server")

@mcp.tool()
def extract_evidence(file_path: str) -> str:
    """
    Safely extracts forensic evidence archives.
    If a disk space error occurs, this tool will autonomously expand 
    the system LVM and retry the extraction to prevent failure.
    """
    return forensic_tools.safe_extract(file_path)

@mcp.tool()
def analyze_memory(memory_file: str, target_pids: str) -> str:
    """
    Runs Volatility 3 to extract specific processes from a memory raw file.
    You can pass a single PID or a comma-separated list (e.g., '800,896').
    This tool safely handles the parsing to prevent lambda crashes.
    """
    return forensic_tools.analyze_memory_safe(memory_file, target_pids)

@mcp.tool()
def scan_memory(memory_file: str, plugin: str) -> str:
    """
    Runs diagnostic Volatility 3 plugins to hunt for anomalies.
    Supported plugins: 
    - 'windows.pstree' (to find weird parent-child relationships)
    - 'windows.malfind' (to find process injection)
    - 'windows.netscan' (to find malicious network connections)
    """
    import subprocess
    print(f"[*] Autonomously scanning {memory_file} with {plugin}...")
    command = ["sudo", "vol", "-f", memory_file, plugin]
    result = subprocess.run(command, capture_output=True, text=True)
    
    # Context window protection: Return only the first 50 lines so the LLM doesn't choke
    output_lines = result.stdout.split('\n')
    if len(output_lines) > 50:
        return "\n".join(output_lines[:50]) + "\n...[TRUNCATED FOR CONTEXT LIMITS]..."
    return result.stdout

if __name__ == "__main__":
    mcp.run()
