"use strict";
/* gallery: works → profiles(열) x shots(행). 클릭 토글 재생/정지, 비교용 동시 재생 허용. */
const state = { work: null, data: null };

async function load() {
  const res = await fetch("gallery.json", { cache: "no-store" });
  if (!res.ok) throw new Error("gallery.json load fail: " + res.status);
  state.data = await res.json();
  const works = Object.keys(state.data.works || {});
  if (!works.length) {
    document.getElementById("status").textContent = "산출물 없음 (generate 후 gen-manifest 실행)";
    return;
  }
  // 작품별 페이지(matchgirl.html 등)는 GALLERY_WORK 고정. 없으면 첫 work.
  const fixed = (typeof GALLERY_WORK !== "undefined" && GALLERY_WORK) || null;
  state.work = (fixed && works.includes(fixed)) ? fixed : works[0];
  renderNav(works);
  renderGrid();
}

function renderNav(works) {
  const nav = document.getElementById("works");
  nav.innerHTML = "";
  for (const w of works) {
    const a = document.createElement("a");
    a.href = w + ".html";
    a.textContent = w;
    if (w === state.work) {
      a.className = "active";
      a.onclick = (e) => e.preventDefault();
    }
    nav.appendChild(a);
  }
}

function shotRows(profiles) {
  // 전 프로파일 샷 번호 합집합, 정렬
  const set = new Set();
  for (const p of Object.values(profiles))
    for (const s of p.shots) set.add(s.n + "|" + s.id);
  return [...set].sort().map((k) => k.split("|"));
}

function fmt(v, unit) {
  if (v === null || v === undefined) return "-";
  return (Math.round(v * 10) / 10) + unit;
}

function renderGrid() {
  const profiles = state.data.works[state.work].profiles;
  const pnames = Object.keys(profiles).sort();
  const head = document.getElementById("head-row");
  head.innerHTML = "<th>shot</th>";
  for (const p of pnames) {
    const th = document.createElement("th");
    th.textContent = p;
    const m = (profiles[p].meta) || {};
    if (m.short || m.engine) {
      const sub = document.createElement("span");
      sub.className = "prof-label";
      sub.textContent = [m.short, m.steps ? m.steps + "st" : "", m.resolution || ""].filter(Boolean).join(" · ");
      sub.title = (m.title ? m.title + "\n" : "") + (m.purpose || "") + (m.engine ? "\n" + m.engine : "");
      th.appendChild(document.createElement("br"));
      th.appendChild(sub);
    }
    head.appendChild(th);
  }
  const body = document.getElementById("grid-body");
  body.innerHTML = "";
  const byProf = {};
  for (const p of pnames) {
    byProf[p] = {};
    for (const s of profiles[p].shots) byProf[p][s.n] = s;
  }
  for (const [n, id] of shotRows(profiles)) {
    const tr = document.createElement("tr");
    const th = document.createElement("th");
    th.innerHTML = n + '<span class="shot-id" title="' + esc(id) + '">' + esc(id) + "</span>";
    tr.appendChild(th);
    for (const p of pnames) {
      const td = document.createElement("td");
      const s = byProf[p][n];
      if (!s) {
        td.className = "cell empty";
        td.textContent = "—";
      } else {
        td.className = "cell";
        td.appendChild(cellEl(s));
      }
      tr.appendChild(td);
    }
    body.appendChild(tr);
  }
  document.getElementById("status").textContent =
    state.work + ": " + pnames.length + " profiles";
}

function esc(s) {
  return String(s == null ? "" : s).replace(/[&<>"]/g, (c) => ({"&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;"}[c]));
}

function cellEl(s) {
  const wrap = document.createElement("div");
  const v = document.createElement("video");
  const base = (typeof GALLERY_BASE !== "undefined" ? GALLERY_BASE : "../");
  // 절대 URL base(Releases 등)는 에셋이 flat하므로 basename만 붙임
  v.src = (/^https?:\/\//.test(base) ? base + s.mp4.split("/").pop() : base + s.mp4);
  v.preload = "metadata";
  v.playsInline = true;   // muted 불필요: 클릭 제스처 재생이라 오디오 허용됨
  v.title = (s.id || "") + "\n" + (s.prompt || "");
  v.onclick = () => toggle(v, st);
  const meta = document.createElement("div");
  meta.className = "meta";
  const st = document.createElement("span");
  const info = document.createElement("span");
  info.textContent = fmt(s.dur_s, "s") + " · e2e " + fmt(s.e2e_s, "s") + (s.steps ? " · " + s.steps + "st" : "");
  info.title = s.prompt || "";
  meta.appendChild(st);
  meta.appendChild(info);
  v.onplay = () => { st.textContent = "▶"; st.className = "playing"; };
  v.onpause = () => { st.textContent = ""; st.className = ""; };
  wrap.appendChild(v);
  wrap.appendChild(meta);
  return wrap;
}

function toggle(v, st) {
  if (v.paused) { v.play().catch((e) => { st.textContent = "ERR"; }); }
  else v.pause();
}

function pauseAll() {
  document.querySelectorAll("#grid video").forEach((v) => v.pause());
}
function playAll() {
  document.querySelectorAll("#grid video").forEach((v) => {
    v.play().catch(() => {});
  });
}

document.getElementById("pause-all").onclick = pauseAll;
document.getElementById("play-all").onclick = playAll;
document.addEventListener("keydown", (e) => { if (e.key === "Escape") pauseAll(); });

load().catch((e) => {
  document.getElementById("status").textContent = String(e);
});
