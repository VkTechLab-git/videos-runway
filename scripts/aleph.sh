#!/bin/bash
# Gera com aleph2, espera terminar e baixa o resultado.
# Uso: scripts/aleph.sh <videoUri> <prompt.txt> <saida.mp4> [seed=4242]
set -euo pipefail
uri=$1; prompt=$2; out=$3; seed=${4:-4242}
body=$(python3 -c "import json,sys;print(json.dumps({'model':'aleph2','videoUri':sys.argv[1],'promptText':open(sys.argv[2]).read().strip(),'seed':int(sys.argv[3])}))" "$uri" "$prompt" "$seed")
R=$(curl -sS -X POST https://api.dev.runwayml.com/v1/video_to_video \
  -H X-Runway-Version:2024-11-06 -H Content-Type:application/json -d "$body")
echo "$R" >&2
T=$(echo "$R" | python3 -c "import sys,json;print(json.load(sys.stdin)['id'])")
for i in $(seq 1 150); do
  R=$(curl -sS https://api.dev.runwayml.com/v1/tasks/$T -H X-Runway-Version:2024-11-06)
  St=$(echo "$R" | python3 -c "import sys,json;print(json.load(sys.stdin)['status'])")
  [ "$St" = SUCCEEDED ] || [ "$St" = FAILED ] && break
  sleep 8
done
[ "$St" = SUCCEEDED ] || { echo "falhou: $R" >&2; exit 1; }
curl -sSL -o "$out" "$(echo "$R" | python3 -c "import sys,json;print(json.load(sys.stdin)['output'][0])")"
echo "$R" | python3 -c "import sys,json;d=json.load(sys.stdin);print('ok:',d.get('cost'))" >&2
echo "$out"
