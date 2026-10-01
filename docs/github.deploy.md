# 갤러리 앱 배포 (GitHub Pages)

## URL

- 프로덕션: https://tayaee.github.io/video-generation/
- 리포: https://github.com/tayaee/video-generation
- 영상 에셋: `gallery` 릴리스 (https://github.com/tayaee/video-generation/releases/tag/gallery)

## 구조

```
app/                  # 배포 단위 (이 폴더 통째로 Pages 아티팩트)
  index.html          # 껍데기 (타이틀: MiniMax-H3 and ComfyUI Gallery)
  styles.css
  app.js              # 렌더·인플레이스 재생 (GALLERY_BASE 참조)
  config.js           # ★ 비디오 base URL (아래 참조)
  gallery.json        # 생성물 (update-gallery.json.sh가 생성, 직접 편집 금지)
  serve.sh            # 로컬/Codespaces 서빙
scripts/common/update-gallery.json.sh   # results/ 스캔 → app/gallery.json
.github/workflows/deploy.yml    # 배포 워크플로우
```

## 배포 흐름

1. `main`에 `app/**` 푸시 (또는 Actions에서 수동 실행) →
2. `deploy.yml`이 `app/`을 아티팩트로 업로드 → Pages 배포.

## Source: GitHub Actions의 의미 (중요)

- Settings → Pages → Source를 **GitHub Actions**로 선택하면,
  배포 내용은 branch/path 설정과 무관하게 **오직 `deploy.yml`의
  `upload-pages-artifact` → `path: "app"`이 결정**한다.
  즉 `/app`의 파일이 사이트 루트(`/`)로 배포된다.
- 반대로 Source가 branch 방식이면 이 워크플로우는 성공해도 무시되고
  branch의 해당 폴더가 그대로 서빙된다 (2026-10-01에 이 상태라 404가 났음.
  API로 `build_type=workflow` 전환하여 해결済み).
- 배포 대상을 바꾸려면 `deploy.yml`의 `path:`와 `paths:` 트리거를 함께 고친다.
  (`paths: app/**`는 app 변경 때만 워크플로우가 돌게 하는 필터다.)

## 영상 소싱 (중요)

- mp4는 **릴리스 에셋**에서 스트리밍한다. LFS 금지 (Pages 미배포 + 월 1GB quota).
- `app/config.js`의 `GALLERY_BASE`가 전부다. 현재값:
  `https://github.com/tayaee/video-generation/releases/download/gallery/`
- 로컬/Codespaces 서빙 시에는 `../` 로 두면 리포 상대경로로 동작.

## 샷 추가手順 (다음 개발자용)

```bash
# 1) 릴리스에 mp4 업로드 (파일명 기준 매칭, flat)
gh release upload gallery results/matchgirl/profiles/*/shots/11_*.mp4

# 2) manifest 재생성 (SHOTS에 추가)
SHOTS=01,02,03,04,05,06,07,08,09,10,11 WORK=matchgirl ./scripts/common/update-gallery.json.sh

# 3) 스트리밍 확인 후 푸시 (app/** 변경이 배포 트리거)
git add app/gallery.json && git commit -m "docs: gallery adds shot 11" && git push origin main
```

## 로컬 확인

```bash
SHOTS=03 ./app/serve.sh   # :8001/app/ (LFS 부분 pull + manifest + 서빙)
```

## 현재 상태 (2026-10-01)

- work: matchgirl, 전샷 01~36 (s50은 생성 중, 나오는 대로 추가)
- 프로파일 5열: s04 < s08 < s10 < s20 < s50 (이름순 정렬 = 저→고화질)
- 메타(sidecar dur/e2e/prompt)와 프로파일 설명(profile.json short/engine)이 헤딩·셀에 표시
