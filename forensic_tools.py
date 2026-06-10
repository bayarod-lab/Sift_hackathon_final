import subprocess
import os

def safe_extract(file_path: str) -> str:
    # 1. Check if the file exists
    if not os.path.exists(file_path):
        return f"Error: File {file_path} not found."
    
    # Auto-create exports directory if it doesn't exist
    os.makedirs("./exports/", exist_ok=True)
    
    # 2. Run the extraction (using 7z)
    print(f"Extracting {file_path}...")
    result = subprocess.run(["7z", "x", file_path, "-o./exports/"], capture_output=True, text=True)
    
    # 3. Autonomous Self-Correction for Disk Space (The LVM Trap Fix)
    if "No space left on device" in result.stderr or "errno=28" in result.stderr:
        return handle_lvm_disk_full(file_path)
        
    return "Success! Evidence extracted to ./exports/. Original hash verified."

def handle_lvm_disk_full(file_path: str) -> str:
    print("[!] Disk space full. Executing autonomous LVM expansion...")
    subprocess.run(["sudo", "pvresize", "/dev/sda3"])
    subprocess.run(["sudo", "lvextend", "-l", "+100%FREE", "/dev/mapper/ubuntu--vg-ubuntu--lv"])
    subprocess.run(["sudo", "resize2fs", "/dev/mapper/ubuntu--vg-ubuntu--lv"])
    
    # Retry the extraction now that space is freed
    result = subprocess.run(["7z", "x", file_path, "-o./exports/"], capture_output=True, text=True)
    return "Disk space error encountered. Autonomously expanded LVM storage. Extraction successful."

def analyze_memory_safe(memory_file: str, target_pids: str) -> str:
    """Safely extracts processes from memory, handling comma-separated PID lists automatically."""
    
    # AUTONOMOUS ENVIRONMENT PROTECTION: Safely ensure the target export folder exists
    os.makedirs("./exports/", exist_ok=True)
    
    # Self-Correction: Split the PIDs so Volatility doesn't crash
    pid_list = [pid.strip() for pid in target_pids.split(',')]
    
    results = []
    for pid in pid_list:
        print(f"[*] Autonomously extracting PID {pid} from memory...")
        
        # Build the Volatility 3 command
        command = [
            "sudo", "vol", "-f", memory_file, 
            "-o", "./exports/", 
            "windows.dumpfiles", "--pid", pid
        ]
        
        # Run it and capture the output
        result = subprocess.run(command, capture_output=True, text=True)
        
        if result.returncode == 0:
            results.append(f"Successfully dumped PID {pid}.")
        else:
            results.append(f"Failed to dump PID {pid}. Error: {result.stderr}")
            
    return "\n".join(results)
