import sys
import subprocess

def scan_memory(memory_file: str, plugin: str):
    print(f"[*] Autonomously scanning {memory_file} with {plugin}...", file=sys.stderr)
    
    # Removed 'sudo' to prevent interactive password hangs. 
    # If vol requires sudo, you should run the entire analyze.sh script with sudo instead.
    command = ["vol", "-f", memory_file, plugin]
    
    try:
        result = subprocess.run(command, capture_output=True, text=True, check=True)
        # Print the FULL output so it can be piped into memory_scan_results.txt
        print(result.stdout)
    except subprocess.CalledProcessError as e:
        print(f"Error running Volatility: {e.stderr}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 run_scan.py <memory_file>", file=sys.stderr)
        sys.exit(1)
        
    target_file = sys.argv[1]
    scan_memory(target_file, "windows.pstree")
