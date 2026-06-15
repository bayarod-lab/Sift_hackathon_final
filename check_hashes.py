import json, sys, urllib.request, os

facts_path = sys.argv[1]
out_path = sys.argv[2] if len(sys.argv) > 2 else None
facts = json.load(open(facts_path))

hashes = [
    f["artifact_value"] for f in facts
    if len(f.get("artifact_value", "")) in (32, 64)
    and all(c in "0123456789abcdefABCDEF" for c in f["artifact_value"])
]

results = []
VT_KEY = os.environ.get("VT_API_KEY", "")

for h in hashes[:5]:  # cap at 5 to avoid rate limits
    try:
        if VT_KEY:
            req = urllib.request.Request(
                f"https://www.virustotal.com/api/v3/files/{h}",
                headers={"x-apikey": VT_KEY}
            )
            with urllib.request.urlopen(req, timeout=10) as r:
                data = json.loads(r.read())
                stats = data["data"]["attributes"]["last_analysis_stats"]
                results.append({"hash": h, "malicious": stats.get("malicious", 0), "source": "virustotal"})
        else:
            # NSRL fallback — just flag if hash is suspiciously absent from common knowledge
            results.append({"hash": h, "malicious": "unknown", "source": "no_api_key"})
    except Exception as e:
        results.append({"hash": h, "error": str(e)})

if out_path:
    json.dump(results, open(out_path, "w"), indent=2)
    print(f"[+] Hash reputation results written to {out_path}")

# Annotate facts with VT hits
for f in facts:
    for r in results:
        if f.get("artifact_value") == r.get("hash") and r.get("malicious", 0) > 0:
            f["iocs"].append(f"VT_MALICIOUS:{r['malicious']}")
            f["confidence"] = "High"

json.dump(facts, open(facts_path, "w"), indent=2)
