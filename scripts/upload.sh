#!/bin/bash
# Envia um arquivo local ao Runway e imprime o runwayUri (válido por ~24 h).
# Uso: scripts/upload.sh <arquivo>
set -euo pipefail
f=$1
J=$(curl -sS -X POST https://api.dev.runwayml.com/v1/uploads \
  -H X-Runway-Version:2024-11-06 -H Content-Type:application/json \
  -d "{\"filename\":\"$(basename "$f")\",\"type\":\"ephemeral\"}")
mapfile -t A < <(echo "$J" | python3 -c "import sys,json;d=json.load(sys.stdin);[print('-F\n'+k+'='+v) for k,v in d['fields'].items()]")
U=$(echo "$J" | python3 -c "import sys,json;print(json.load(sys.stdin)['uploadUrl'])")
c=$(curl -sS -o /dev/null -w "%{http_code}" "${A[@]}" -F "file=@$f" "$U")
[ "$c" = 204 ] || { echo "falha no upload: HTTP $c" >&2; exit 1; }
echo "$J" | python3 -c "import sys,json;print(json.load(sys.stdin)['runwayUri'])"
