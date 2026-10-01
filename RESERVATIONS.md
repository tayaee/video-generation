# 예약 작업 목록 (Reservations)

## 상태: R1·R2 완료 (2026-10-01, 미커밋 — 검토 후 수동 커밋)

실행 기록: `/tmp/migrate-r1r2.sh` (dry-run `/tmp/vg-test` 통과 후 실리포 적용),
실행 로그 `/tmp/mig-real.log`. 커밋은 하지 않음.

## R1. 루트 디렉토리 레이아웃 변경 (완료)

이하 원래 계획대로 적용됨 (산출물은 `results/` 잔류, `d1` 삭제, `video/` 제거).

## R2. 프로파일 기계식 개명 (완료)

- `preview` → `s10-576p-vllm-t2va`
- `full` → `s50-576p-vllm-t2va`
- `turbo` → `s08-352p-comfy-turbo`

---

## 아래는 실행 전 원본 기록 (참고용)

## R1. 루트 디렉토리 레이아웃 변경 (예약)

목표 트리:

```
./.gitattributes
./.gitignore
./results/matchgirl/profiles/*/shots/        # 산출물만 잔류 (그대로)
./scripts/common/assemble.sh                  # video/showcase/assemble.sh 이동
./scripts/common/mirror-results.sh            # ./mirror-results.sh 이동
./scripts/common/sync-results.sh              # ./sync-results.sh 이동
./docs/h3.showcases.md                        # video/showcase/h3.showcases.md 이동
./scripts/matchgirl/profiles/*/generate.sh    # results 아래 generate.sh 이동
./scripts/showcase/t2v_first.json             # video/showcase/t2v_first.json 이동
./setup/h3.cluster.env                        # video/h3.cluster.env 이동
./setup/h3.deploy.md
./setup/h3.instruction.txt
./setup/infra/...                             # video/infra/... 전체 이동
```

함께 고쳐야 할 내부 경로 (git mv 후 sed/검증):

- 3개 generate.sh: `OUTDIR` 기본값을 `$REPO_ROOT/results/matchgirl/profiles/<profile>/shots`로
  (`$BASEDIR/shots` 상대경로는 스크립트 이동 시 산출물이 따라가서 깨짐).
  `REPO_ROOT` 계산(`$BASEDIR/../../../..`)은 이동 전후 깊이가 같아 그대로 동작.
- turbo generate.sh: `TEMPLATE` → `$REPO_ROOT/scripts/showcase/t2v_first.json`.
- assemble.sh: `REPO=$BASEDIR/../..` 그대로 동작 (깊이 동일). 기본 INDIR/OUT은 results 기준이라 유지.
- proxy-up.sh: `h3.cluster.env` 상대 참조(`../../../../`) 그대로 동작 (깊이 동일). 단 파일 위치 변경 확인.
- docs(h3.showcases.md): 모든 경로 표기 갱신.
- 정리 대상: `d1` (추적 안 됨, ps 덤프 잔재 — 이동 말고 삭제), `video/results/` 빈 트리.

## R2. 프로파일 기계식 개명 (예약, R1과 같은 창구에서 처리)

`s##-높이p-엔진-알고리즘` 규칙 (`ls` 정렬 = 저화질→고화질 작업 순서):

- `preview` → `s10-576p-vllm-t2va`
- `full` → `s50-576p-vllm-t2va`
- `turbo` → `s08-352p-comfy-turbo`

연동 수정: OUTDIR 기본값 내 프로파일명(`basename $BASEDIR` 자동 추종이라 코드 변경 불필요,
  단 하드코딩된 경로·문서·sidecar 기존값은 그대로 둠), assemble.sh 기본 프로파일명,
  showcases.md 매핑표 (기계식명 = 티어 별칭 병기).
추가 옵션 고정 시 suffix (`-flf`, `-fs6`, `-r1`)는 해당 프로파일 확정 때 부여.
