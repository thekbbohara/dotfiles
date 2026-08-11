#!/bin/bash

IGPU="?"
NGPU=""

if command -v intel_gpu_top >/dev/null 2>&1; then
    raw=$(timeout 2 intel_gpu_top -J -s 1000 -o - 2>/dev/null | head -c 8000)
    IGGPU=$(echo "$raw" | python3 -c "
import sys, json
data = sys.stdin.read().lstrip()
try:
    obj, _ = json.JSONDecoder().raw_decode(data)
except Exception:
    print('?')
    sys.exit(0)
if 'GT' in obj and isinstance(obj['GT'], dict):
    print(int(round(obj['GT'].get('busy', 0))))
else:
    vals = [v for v in obj.get('engines', {}).values() if isinstance(v, (int, float))]
    print(int(round(max(vals))) if vals else 0)
")
fi

if command -v nvidia-smi >/dev/null 2>&1; then
    NGPU=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | tr -d ' ' | head -1)
fi

if [ "$IGPU" != "?" ] && [ -n "$NGPU" ]; then
    echo "${IGPU}% ${NGPU}%"
elif [ "$IGPU" != "?" ]; then
    echo "${IGPU}%"
elif [ -n "$NGPU" ]; then
    echo "${NGPU}%"
else
    echo "?"
fi
