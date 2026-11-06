#!/usr/bin/env bash
# Dumps the current Cloudflare, Tailscale and Portainer config to
# terraform/.snapshot/ (gitignored), with secret values blanked, so the
# Terraform can be written to match what's live. Read-only: it only GETs.
#
#   terraform/tf run ./snapshot.sh            # everything
#   terraform/tf run ./snapshot.sh portainer  # one section
#
# Credentials come from the Bitwarden item (see tf).
set -uo pipefail
cd "$(dirname "$0")"
OUT=.snapshot
mkdir -p "$OUT"

# Reads JSON on stdin, blanks anything that looks like a secret, writes it out.
redact() {
  python3 -I -c '
import json, re, sys
SECRET = re.compile(r"(pass(word|key)?|api_?key|token|secret|cookie|authkey)$", re.I)
def walk(v, parent=""):
    if isinstance(v, dict):
        # *arr "fields": {"name": ..., "value": ..., "privacy": ...}
        if "value" in v and ("privacy" in v or "name" in v):
            n = str(v.get("name", ""))
            if v.get("privacy", "normal") != "normal" or SECRET.search(n.split(".")[-1]) or parent == "Env":
                v = dict(v, value="<redacted>" if v.get("value") not in (None, "") else v.get("value"))
        return {k: ("<redacted>" if SECRET.search(k) and isinstance(x, str) and x else walk(x, k)) for k, x in v.items()}
    if isinstance(v, list):
        return [walk(x, parent) for x in v]
    return v
try:
    data = json.load(sys.stdin)
except ValueError:
    sys.exit("not JSON (wrong URL or key?)")
json.dump(walk(data), sys.stdout, indent=2, sort_keys=True)
print()
'
}

# get <file> <url> <curl header args...>
get() {
  local file=$1 url=$2; shift 2
  if curl -sSf "$@" "$url" | redact > "$OUT/$file.tmp"; then
    mv "$OUT/$file.tmp" "$OUT/$file"; echo "ok    $file"
  else
    rm -f "$OUT/$file.tmp"; echo "FAIL  $file  ($url)"
  fi
}

need() { for v in "$@"; do [ -n "${!v:-}" ] || { echo "export $v first"; exit 1; }; done; }

portainer() {
  need PORTAINER_API_KEY
  local P=${PORTAINER_ENDPOINT:-http://10.10.2.10:9000}/api H=(-H "X-API-Key: $PORTAINER_API_KEY")
  get portainer-endpoints.json "$P/endpoints" "${H[@]}"
  get portainer-stacks.json "$P/stacks" "${H[@]}"
}

cloudflare() {
  need CLOUDFLARE_API_TOKEN
  local C=https://api.cloudflare.com/client/v4 H=(-H "Authorization: Bearer $CLOUDFLARE_API_TOKEN")
  get cloudflare-zone.json "$C/zones?name=${ZONE:-gt3.dev}" "${H[@]}"
  local zone
  zone=$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["result"][0]["id"])' "$OUT/cloudflare-zone.json") || return
  get cloudflare-dns.json "$C/zones/$zone/dns_records?per_page=5000" "${H[@]}"
}

tailscale() {
  need TAILSCALE_OAUTH_CLIENT_ID TAILSCALE_OAUTH_CLIENT_SECRET
  local T=https://api.tailscale.com/api/v2 tok
  tok=$(curl -sSf -d "client_id=$TAILSCALE_OAUTH_CLIENT_ID" -d "client_secret=$TAILSCALE_OAUTH_CLIENT_SECRET" \
        "$T/oauth/token" | python3 -I -c 'import json,sys; print(json.load(sys.stdin)["access_token"])') \
    || { echo "FAIL  tailscale OAuth token"; return; }
  local H=(-H "Authorization: Bearer $tok")
  # The policy file is HuJSON (comments allowed), so it's saved as-is.
  if curl -sSf "${H[@]}" -H "Accept: application/hujson" "$T/tailnet/-/acl" > "$OUT/tailscale-policy.hujson"; then
    echo "ok    tailscale-policy.hujson"; else echo "FAIL  tailscale-policy.hujson"; fi
  get tailscale-devices.json "$T/tailnet/-/devices?fields=all" "${H[@]}"
  get tailscale-settings.json "$T/tailnet/-/settings" "${H[@]}"
}

if [ $# -eq 0 ]; then set -- cloudflare tailscale portainer; fi
for s in "$@"; do "$s"; done
