import sys
import json

def verify_schema(filepath):
    try:
        with open(filepath, 'r') as f:
            data = json.load(f)
            
        # 1. Check Root Keys
        required_root = ['case_id', 'target', 'intent_verdict', 'summary', 'artifacts']
        for key in required_root:
            if key not in data:
                print(f"[-] Schema Error: Missing root key '{key}'")
                sys.exit(1)
                
        # 2. Check Artifact Keys & Strict Confidence Values
        required_artifact_keys = [
            'name', 'type', 'value', 'description', 'confidence', 
            'recommended_validation', 'risk_score', 'priority', 'review_status'
        ]
        
        valid_confidence_levels = ['low', 'medium', 'high']
        
        for idx, artifact in enumerate(data['artifacts']):
            for key in required_artifact_keys:
                if key not in artifact:
                    print(f"[-] Schema Error: Artifact #{idx} missing key '{key}'")
                    sys.exit(1)
            
            # STRICT ENFORCEMENT: Block "PENDING VALIDATION" and other hallucinations
            conf_value = str(artifact.get('confidence', '')).strip().lower()
            if conf_value not in valid_confidence_levels:
                print(f"[-] Schema Error: Artifact #{idx} has invalid confidence '{conf_value}'. Must be Low, Medium, or High.")
                sys.exit(1)
                
        print("[+] Schema validation passed.")
        sys.exit(0)
        
    except json.JSONDecodeError as e:
        print(f"[-] JSON Parsing Error: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"[-] Unexpected Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 verify_schema.py <json_file>")
        sys.exit(1)
    verify_schema(sys.argv[1])
