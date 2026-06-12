import json
import sys

if len(sys.argv) < 2:
    print("[-] Usage: python3 verify_schema.py <path_to_ledger.json>")
    sys.exit(1)

try:
    with open(sys.argv[1], 'r') as f:
        data = json.load(f)
    
    # Validate required root keys
    for root_key in ["case_id", "artifacts"]:
        if root_key not in data:
            print(f"[-] Validation Error: Missing root key '{root_key}'")
            sys.exit(1)
            
    # Validate structure of individual forensic artifacts
    for index, artifact in enumerate(data["artifacts"]):
        for key in ["name", "description", "review_status"]:
            if key not in artifact:
                print(f"[-] Validation Error: Artifact at index {index} is missing key '{key}'")
                sys.exit(1)
                
    print("[+] Forensic Quality Control: Schema validation passed successfully.")
    sys.exit(0)

except json.JSONDecodeError as je:
    print(f"[-] Validation Error: Malformed JSON syntax detected - {je}")
    sys.exit(1)
except Exception as e:
    print(f"[-] Validation Error: System exception occurred - {e}")
    sys.exit(1)
