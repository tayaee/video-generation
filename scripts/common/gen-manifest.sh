#!/usr/bin/env bash
# scripts/common/gen-manifest.sh: results/ 아래 산출물 스캔 → docs/gallery.json 생성.
#   ./gen-manifest.sh                    # 전체 work·전체 샷
#   WORK=matchgirl ./gen-manifest.sh     # 특정 work만
#   SHOTS=03 ./gen-manifest.sh           # 특정 샷만 (콤마 구분: SHOTS=03,04,05)
# sidecar(<stem>.json)에서 dur/e2e/prompt를 읽어 함께 넣는다.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK_FILTER="${WORK:-}"
SHOTS_FILTER="${SHOTS:-}"
OUT="$REPO/docs/gallery.json"

mkdir -p "$REPO/app"
WORK="$WORK_FILTER" SHOTS="$SHOTS_FILTER" SRC="$REPO/results" DST="$OUT" python3 - <<'PYEOF'
import json, os, re

src = os.environ["SRC"]
work_filter = {w for w in os.environ["WORK"].split(",") if w} if os.environ["WORK"] else None
shots_filter = {s for s in os.environ["SHOTS"].split(",") if s} if os.environ["SHOTS"] else None

works = {}
if not os.path.isdir(src):
    json.dump({"works": {}}, open(os.environ["DST"], "w"))
    print("no results/, empty manifest")
    raise SystemExit

for work in sorted(os.listdir(src)):
    wdir = os.path.join(src, work)
    if not os.path.isdir(wdir):
        continue
    if work_filter and work not in work_filter:
        continue
    profiles = {}
    pdir = os.path.join(wdir, "profiles")
    if not os.path.isdir(pdir):
        continue
    for prof in sorted(os.listdir(pdir)):
        sdir = os.path.join(pdir, prof, "shots")
        if not os.path.isdir(sdir):
            continue
        shots = []
        for f in sorted(os.listdir(sdir)):
            if not f.endswith(".mp4"):
                continue
            m = re.match(r"^(\d{2})_(.+?)(?:_s\d+|_t\d+|_turbo\d*|_turbo)?\.mp4$", f)
            if not m:
                continue
            n, sid = m.group(1), m.group(2)
            if shots_filter and n not in shots_filter:
                continue
            stem = f[:-4]
            meta = {}
            jp = os.path.join(sdir, stem + ".json")
            if os.path.isfile(jp):
                try:
                    meta = json.load(open(jp))
                except Exception:
                    meta = {}
            speed = meta.get("speed", {}) if isinstance(meta, dict) else {}
            method = meta.get("method", {}) if isinstance(meta, dict) else {}
            shots.append({
                "n": n,
                "id": sid,
                "mp4": f"results/{work}/profiles/{prof}/shots/{f}",
                "dur_s": speed.get("video_dur_s"),
                "e2e_s": speed.get("e2e_s"),
                "steps": (method.get("params", {}) or {}).get("num_inference_steps",
                           (method.get("params", {}) or {}).get("steps")),
                "prompt": (method.get("prompt") if isinstance(method, dict) else None),
            })
        if shots:
            profiles[prof] = {"shots": shots}
    if profiles:
        works[work] = {"profiles": profiles}

json.dump({"works": works}, open(os.environ["DST"], "w"), ensure_ascii=False, indent=1)
n_shots = sum(len(p["shots"]) for w in works.values() for p in w["profiles"].values())
print(f"manifest: {len(works)} works, {n_shots} shots -> {os.environ['DST']}")
PYEOF
