/* 갤러리 비디오 base URL.
 * - Codespace/로컬 서빙(리포 루트): "" 그대로 두면 docs/ 기준 ../results/... 로 해석.
 * - GitHub Pages(/docs 소스): mp4를 리포에 둘 수 없으므로(LFS 미지원) Releases
 *   에셋(또는 외부 스토리지) 절대 URL로 교체. 예:
 *   var GALLERY_BASE = "https://github.com/<user>/<repo>/releases/download/gallery/";
 *   (끝 슬래시 필수. gallery.json의 mp4 상대경로 뒤에 붙음)
 */
var GALLERY_BASE = "../";
