// Shared helpers for the plain pages (no libraries).
const $ = (s, r = document) => r.querySelector(s);
function h(tag, attrs, ...kids) {
  const e = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs || {})) { if (k === 'class') e.className = v; else if (k.startsWith('on')) e.addEventListener(k.slice(2), v); else if (v !== false && v != null) e.setAttribute(k, v === true ? '' : v); }
  for (const k of kids.flat()) if (k != null && k !== false) e.append(k.nodeType ? k : document.createTextNode(k));
  return e;
}
async function call(method, url, body) {
  const r = await fetch(url, { method, headers: { 'Content-Type': 'application/json' }, body: body ? JSON.stringify(body) : undefined });
  let data = null; try { data = await r.json(); } catch (e) { /* no body */ }
  return { ok: r.ok, status: r.status, data: data || {} };
}
const MONTHS = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
const fmtDate = s => { if (!s) return '-'; const [y, m, d] = s.split('-'); return `${Number(d)} ${MONTHS[Number(m) - 1]} ${y}`; };
const fmtDateTime = ms => { if (!ms) return '-'; const d = new Date(ms); return `${d.getDate()} ${MONTHS[d.getMonth()]} ${d.getFullYear()}, ${String(d.getHours()).padStart(2,'0')}:${String(d.getMinutes()).padStart(2,'0')}`; };
const mmss = ms => { if (ms < 0) ms = 0; const s = Math.floor(ms / 1000); return `${String(Math.floor(s / 60)).padStart(2,'0')}:${String(s % 60).padStart(2,'0')}`; };
function titleWin(title, sub) { return h('div', { class: 'titlebar' }, h('span', { class: 'dot' }), h('span', {}, title), sub ? h('span', { class: 'sub' }, sub) : null); }
// Collapsible section. open: start open. Returns { el, body, setDone, open, close, isOpen }
function section(title, startOpen) {
  const body = h('div', { class: 'sec-b' });
  const tick = h('span', { class: 'tick' });
  const head = h('button', { class: 'sec-h', type: 'button' }, h('span', { class: 'arrow' }, '▸'), title, tick);
  const el = h('div', { class: 'sec' + (startOpen ? ' open' : '') }, head, body);
  const sync = () => { $('.arrow', el).textContent = el.classList.contains('open') ? '▾' : '▸'; };
  head.addEventListener('click', () => { el.classList.toggle('open'); sync(); });
  sync();
  return { el, body,
    open() { el.classList.add('open'); sync(); }, close() { el.classList.remove('open'); sync(); },
    setDone(d) { tick.textContent = d ? '✓ done' : ''; } };
}
function kv(rows) { const dl = h('dl', { class: 'kv' }); for (const [k, v] of rows) dl.append(h('dt', {}, k), h('dd', {}, v == null || v === '' ? '-' : String(v))); return dl; }
