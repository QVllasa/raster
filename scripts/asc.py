# /// script
# requires-python = ">=3.11"
# dependencies = ["pyjwt", "cryptography", "requests"]
# ///
"""Kleiner App-Store-Connect-API-Client.

Aufruf:  uv run scripts/asc.py GET /v1/apps
         uv run scripts/asc.py POST /v1/bundleIds '{"data": {...}}'
Schlüssel über Umgebungsvariablen: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_FILE.
"""
import json, os, sys, time
import jwt, requests

BASE = "https://api.appstoreconnect.apple.com"

def token() -> str:
    key = open(os.path.expanduser(os.environ["ASC_KEY_FILE"])).read()
    now = int(time.time())
    return jwt.encode({"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 1100,
                       "aud": "appstoreconnect-v1"}, key, algorithm="ES256",
                      headers={"kid": os.environ["ASC_KEY_ID"]})

def call(method: str, path: str, body=None):
    url = path if path.startswith("http") else BASE + path
    r = requests.request(method, url, headers={"Authorization": f"Bearer {token()}",
                                               "Content-Type": "application/json"},
                         data=json.dumps(body) if body is not None else None, timeout=60)
    try:
        data = r.json() if r.content else {}
    except ValueError:
        data = {"raw": r.text}
    return r.status_code, data

if __name__ == "__main__":
    method, path = sys.argv[1], sys.argv[2]
    body = json.loads(sys.argv[3]) if len(sys.argv) > 3 else None
    status, data = call(method, path, body)
    print(status)
    print(json.dumps(data, indent=1, ensure_ascii=False))
