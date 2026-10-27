'use strict';
// Kranti transport (Gold) prototype: a deliberately small demo back end.
// One file, one SQLite database file, no build step. NOT production code:
// SMS is a fake inbox, email is only recorded, and there is no PDF, QR or anchor.
const express = require('express');
const Database = require('better-sqlite3');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const PORT = Number(process.env.PORT || 4180);
const PUBLIC_URL = (process.env.PUBLIC_URL || `http://localhost:${PORT}`).replace(/\/$/, '');
const DB_FILE = process.env.DB_FILE || path.join(__dirname, 'kranti-transport.db');
const CODE_SECRET = process.env.CODE_SECRET || 'demo-only-secret-change-me';
const MIN = 60 * 1000;
const FILL_WINDOW = 25 * MIN;            // requester fills within 25 minutes
const APPROVE_WINDOW = 25 * MIN;         // transporter decides within 25 minutes
const CONFIRM_LINK_WINDOW = 24 * 60 * MIN; // other party's end-confirmation link
const CODE_VALID = 10 * MIN;
const CODE_COOLDOWN = 60 * 1000;
const CODES_PER_HOUR = 5;
const MAX_WRONG = 3;
const GRACE_MS = 3 * 24 * 60 * MIN;
const ALPHABET = '0123456789ABCDEFGHJKMNPQRSTVWXYZ'; // Crockford base32

const SCHEMA = `
CREATE TABLE IF NOT EXISTS org (id INTEGER PRIMARY KEY, name TEXT, gstin TEXT, address TEXT, phone TEXT, email TEXT, plan TEXT, valid_until TEXT);
CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY, org_id INTEGER, name TEXT, email TEXT UNIQUE, pass_hash TEXT, role TEXT);
CREATE TABLE IF NOT EXISTS party (id INTEGER PRIMARY KEY, org_id INTEGER, name TEXT, gstin TEXT, phone TEXT, address TEXT, UNIQUE(org_id, gstin));
CREATE TABLE IF NOT EXISTS driver (id INTEGER PRIMARY KEY, org_id INTEGER, name TEXT, phone TEXT, licence_no TEXT);
CREATE TABLE IF NOT EXISTS vehicle (id INTEGER PRIMARY KEY, org_id INTEGER, reg_no TEXT, vtype TEXT);
CREATE TABLE IF NOT EXISTS svc (
  id INTEGER PRIMARY KEY, org_id INTEGER, code TEXT, template TEXT, status TEXT,
  created_at INTEGER, order_date TEXT, expires_at INTEGER, submitted_at INTEGER, decided_at INTEGER, alert_ack INTEGER DEFAULT 0,
  req_name TEXT, req_gstin TEXT, req_phone TEXT, req_address TEXT, req_alt_phone TEXT, req_email TEXT,
  goods_desc TEXT, goods_nos INTEGER, goods_unit TEXT, goods_weight TEXT,
  lift_from TEXT, lift_to TEXT, deliver_from TEXT, deliver_to TEXT,
  oth_gstin TEXT, oth_name TEXT, oth_address TEXT, oth_site TEXT, oth_phone TEXT, oth_alt_phone TEXT, oth_email TEXT,
  driver_id INTEGER, driver_name TEXT, driver_phone TEXT, vehicle_no TEXT, vehicle_type TEXT,
  ref_receipt TEXT, locked_at INTEGER, confirm_sent_at INTEGER, sealed_at INTEGER);
CREATE TABLE IF NOT EXISTS link (id INTEGER PRIMARY KEY, svc_id INTEGER, purpose TEXT, token_hash TEXT UNIQUE, expires_at INTEGER, revoked_at INTEGER, created_at INTEGER);
CREATE TABLE IF NOT EXISTS code_challenge (id INTEGER PRIMARY KEY, svc_id INTEGER, code_hmac TEXT, created_at INTEGER, expires_at INTEGER, attempts INTEGER DEFAULT 0, status TEXT DEFAULT 'open');
CREATE TABLE IF NOT EXISTS sms (id INTEGER PRIMARY KEY, svc_id INTEGER, to_phone TEXT, kind TEXT, body TEXT, created_at INTEGER);
CREATE TABLE IF NOT EXISTS event (id INTEGER PRIMARY KEY, svc_id INTEGER, type TEXT, detail TEXT, created_at INTEGER);
CREATE TABLE IF NOT EXISTS gdrn (id INTEGER PRIMARY KEY, svc_id INTEGER UNIQUE, akrn TEXT UNIQUE, seal_hash TEXT, fingerprint TEXT, record TEXT, sealed_at INTEGER);
CREATE TABLE IF NOT EXISTS email_log (id INTEGER PRIMARY KEY, svc_id INTEGER, to_role TEXT, to_email TEXT, status TEXT, created_at INTEGER);
`;

const fresh = !fs.existsSync(DB_FILE);
const db = new Database(DB_FILE);
db.pragma('journal_mode = WAL');
db.exec(SCHEMA);

// ---------- small helpers ----------
const now = () => Date.now();
const sha256 = s => crypto.createHash('sha256').update(String(s)).digest('hex');
const newToken = () => crypto.randomBytes(16).toString('base64url'); // 128 random bits
const codeHmac = (svcId, code) => crypto.createHmac('sha256', CODE_SECRET).update(`${svcId}:${code}`).digest('hex');
const safeEq = (a, b) => { const A = Buffer.from(String(a)), B = Buffer.from(String(b)); return A.length === B.length && crypto.timingSafeEqual(A, B); };
const mask = p => (p ? '******' + String(p).slice(-4) : '');
const todayIST = () => new Date(Date.now() + 330 * MIN).toISOString().slice(0, 10);
const pad = (n, w) => String(n).padStart(w, '0');
const str = v => (v === undefined || v === null ? '' : String(v).trim());
const randChars = n => Array.from({ length: n }, () => ALPHABET[crypto.randomInt(0, 32)]).join('');
const checkChar = s => ALPHABET[[...s].reduce((a, ch) => a + ALPHABET.indexOf(ch), 0) % 32];
function newAkrn() {
  const d = new Date(Date.now() + 330 * MIN);
  const body = randChars(10);
  return `AK-${pad(d.getUTCFullYear() % 100, 2)}${pad(d.getUTCMonth() + 1, 2)}-${body}-${checkChar(body)}`;
}
function canonical(v) {
  if (Array.isArray(v)) return '[' + v.map(canonical).join(',') + ']';
  if (v && typeof v === 'object') return '{' + Object.keys(v).sort().map(k => JSON.stringify(k) + ':' + canonical(v[k])).join(',') + '}';
  return JSON.stringify(v === undefined ? null : v);
}
const log = (svcId, type, detail = '') => db.prepare('INSERT INTO event(svc_id,type,detail,created_at) VALUES (?,?,?,?)').run(svcId, type, detail, now());
const sendSms = (svcId, to, kind, body) => db.prepare('INSERT INTO sms(svc_id,to_phone,kind,body,created_at) VALUES (?,?,?,?,?)').run(svcId, to, kind, body, now());

// ---------- validation (one place, exact messages) ----------
const GSTIN_RE = /^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$/;
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;
const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;
function gstinError(v, label = 'GSTIN') {
  v = str(v).toUpperCase();
  if (!v) return `${label} is required.`;
  if (v.length !== 15) return `${label} must be 15 characters; you entered ${v.length}.`;
  if (!GSTIN_RE.test(v)) return `${label} format is not valid. It should be 2 digits (state code), 5 letters, 4 digits, 1 letter, 1 letter or digit, the letter Z, then 1 letter or digit.`;
  return null;
}
function phoneError(v, label = 'Mobile number', required = true) {
  v = str(v);
  if (!v) return required ? `${label} is required.` : null;
  if (!/^[0-9]+$/.test(v)) return `${label} must contain digits only.`;
  if (v.length !== 10) return `${label} must be 10 digits; you entered ${v.length}.`;
  if (!/^[6-9]/.test(v)) return `${label} must start with 6, 7, 8 or 9.`;
  return null;
}
function emailError(v, label = 'Email', required = true) {
  v = str(v);
  if (!v) return required ? `${label} is required.` : null;
  return EMAIL_RE.test(v) ? null : `${label} is not a valid email address.`;
}
const reqError = (v, label, max = 200) => (!str(v) ? `${label} is required.` : str(v).length > max ? `${label} must be at most ${max} characters.` : null);
const dateError = (v, label) => (!str(v) ? `${label} is required.` : !DATE_RE.test(str(v)) || isNaN(Date.parse(str(v))) ? `${label} must be a valid date.` : null);
const normReg = v => str(v).toUpperCase().replace(/[\s-]/g, '');
const REG_RE = /^[A-Z]{2}[0-9]{1,2}[A-Z]{0,3}[0-9]{4}$/;

const SECTION_FIELDS = {
  you: ['req_alt_phone', 'req_email'],
  goods: ['goods_desc', 'goods_nos', 'goods_unit', 'goods_weight'],
  dates: ['lift_from', 'lift_to', 'deliver_from', 'deliver_to'],
  other: ['oth_gstin', 'oth_name', 'oth_address', 'oth_site', 'oth_phone', 'oth_alt_phone', 'oth_email'],
};
const ALL_FIELDS = Object.values(SECTION_FIELDS).flat();
function validateRequester(f, svc, only) {
  const e = {};
  const other = svc.template === 'load' ? 'Seller' : 'Buyer';
  const site = svc.template === 'load' ? 'Pick-up (load) address' : 'Drop (unload) address';
  const set = (k, msg) => { if (msg) e[k] = msg; };
  set('req_alt_phone', phoneError(f.req_alt_phone, 'Your alternate number', false));
  set('req_email', emailError(f.req_email, 'Your email'));
  set('goods_desc', reqError(f.goods_desc, 'Goods description'));
  const nos = str(f.goods_nos);
  set('goods_nos', !nos ? 'Number of items (nos) is required.' : !/^[0-9]+$/.test(nos) || Number(nos) < 1 ? 'Number of items (nos) must be a whole number of 1 or more.' : null);
  if (str(f.goods_unit).length > 20) e.goods_unit = 'Unit must be at most 20 characters.';
  if (str(f.goods_weight).length > 20) e.goods_weight = 'Weight must be at most 20 characters.';
  for (const [k, l] of [['lift_from', 'Lifting window start'], ['lift_to', 'Lifting window end'], ['deliver_from', 'Expected delivery window start'], ['deliver_to', 'Expected delivery window end']]) set(k, dateError(f[k], l));
  if (!e.lift_from && !e.lift_to && str(f.lift_from) > str(f.lift_to)) e.lift_to = 'Lifting window end cannot be before its start.';
  if (!e.lift_to && str(f.lift_to) < svc.order_date) e.lift_to = 'Lifting window cannot end before today.';
  if (!e.deliver_from && !e.deliver_to && str(f.deliver_from) > str(f.deliver_to)) e.deliver_to = 'Expected delivery window end cannot be before its start.';
  if (!e.lift_from && !e.deliver_from && str(f.deliver_from) < str(f.lift_from)) e.deliver_from = 'Expected delivery cannot start before the lifting window starts.';
  const g = gstinError(f.oth_gstin, `${other} GSTIN`);
  set('oth_gstin', g || (str(f.oth_gstin).toUpperCase() === svc.req_gstin ? `The ${other.toLowerCase()}'s GSTIN cannot be the same as yours.` : null));
  set('oth_name', reqError(f.oth_name, `${other} name`));
  set('oth_address', reqError(f.oth_address, `${other} address`));
  set('oth_site', reqError(f.oth_site, site));
  const p = phoneError(f.oth_phone, `${other} mobile number`);
  set('oth_phone', p || (str(f.oth_phone) === svc.req_phone ? `The ${other.toLowerCase()}'s mobile number cannot be the same as yours.` : null));
  set('oth_alt_phone', phoneError(f.oth_alt_phone, `${other} alternate number`, false));
  set('oth_email', emailError(f.oth_email, `${other} email`, false));
  if (only) for (const k of Object.keys(e)) if (!only.includes(k)) delete e[k];
  return e;
}

// ---------- order logic ----------
function view(o) {
  let status = o.status, flag = null;
  if ((status === 'created' || status === 'submitted') && now() > o.expires_at) status = 'expired';
  if (status === 'active' && o.deliver_to) {
    const due = Date.parse(o.deliver_to + 'T23:59:59.999+05:30');
    if (now() > due + GRACE_MS) flag = 'dormant'; else if (now() > due) flag = 'overdue';
  }
  return { ...o, status, flag };
}
const getSvc = (id, orgId) => { const o = db.prepare('SELECT * FROM svc WHERE id=? AND org_id=?').get(id, orgId); return o ? view(o) : null; };
const rawSvc = id => db.prepare('SELECT * FROM svc WHERE id=?').get(id);
function newLink(svcId, purpose, validMs) {
  db.prepare('UPDATE link SET revoked_at=? WHERE svc_id=? AND purpose=? AND revoked_at IS NULL').run(now(), svcId, purpose);
  const token = newToken();
  db.prepare('INSERT INTO link(svc_id,purpose,token_hash,expires_at,created_at) VALUES (?,?,?,?,?)').run(svcId, purpose, sha256(token), now() + validMs, now());
  return token;
}
function findLink(token, purpose) {
  const l = db.prepare('SELECT * FROM link WHERE token_hash=? AND purpose=?').get(sha256(token), purpose);
  if (!l || l.revoked_at) return null;
  return l;
}
const tmplLabel = t => (t === 'load' ? 'Load (pick-up)' : 'Unload (drop)');

function createOrder(orgId, partyId, template, driverId, vehicleId) {
  const org = db.prepare('SELECT * FROM org WHERE id=?').get(orgId);
  const party = db.prepare('SELECT * FROM party WHERE id=? AND org_id=?').get(partyId, orgId);
  if (!party) throw httpErr(400, 'Choose a requester from your profile.');
  if (!['load', 'unload'].includes(template)) throw httpErr(400, 'Choose Load or Unload.');
  const driver = driverId ? db.prepare('SELECT * FROM driver WHERE id=? AND org_id=?').get(driverId, orgId) : null;
  const vehicle = vehicleId ? db.prepare('SELECT * FROM vehicle WHERE id=? AND org_id=?').get(vehicleId, orgId) : null;
  const t = now();
  const info = db.prepare(`INSERT INTO svc(org_id,template,status,created_at,order_date,expires_at,req_name,req_gstin,req_phone,req_address,
    driver_id,driver_name,driver_phone,vehicle_no,vehicle_type) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`)
    .run(orgId, template, 'created', t, todayIST(), t + FILL_WINDOW, party.name, party.gstin, party.phone, party.address,
      driver ? driver.id : null, driver ? driver.name : null, driver ? driver.phone : null, vehicle ? vehicle.reg_no : null, vehicle ? vehicle.vtype : null);
  const id = Number(info.lastInsertRowid);
  const code = 'SV-' + pad(id, 6);
  db.prepare('UPDATE svc SET code=? WHERE id=?').run(code, id);
  const token = newLink(id, 'requester', FILL_WINDOW);
  sendSms(id, party.phone, 'link-requester', `Kranti: ${org.name} sent you a ${tmplLabel(template)} request ${code}. Fill it within 25 minutes: ${PUBLIC_URL}/r/${token}`);
  log(id, 'created', `${tmplLabel(template)} for ${party.name}; link sent to ${mask(party.phone)}`);
  return id;
}
function resendLink(svc) {
  const org = db.prepare('SELECT * FROM org WHERE id=?').get(svc.org_id);
  db.prepare('UPDATE svc SET status=?, expires_at=?, submitted_at=NULL WHERE id=?').run('created', now() + FILL_WINDOW, svc.id);
  const token = newLink(svc.id, 'requester', FILL_WINDOW);
  sendSms(svc.id, svc.req_phone, 'link-requester', `Kranti: ${org.name} re-sent your ${tmplLabel(svc.template)} request ${svc.code}. Fill it within 25 minutes: ${PUBLIC_URL}/r/${token}`);
  log(svc.id, 'resent', `new link sent to ${mask(svc.req_phone)}; old link revoked`);
}
function applyRequester(svc, f) {
  const set = {};
  for (const k of ALL_FIELDS) set[k] = k === 'oth_gstin' ? str(f[k]).toUpperCase() : str(f[k]);
  set.goods_nos = Number(set.goods_nos);
  const cols = Object.keys(set);
  const first = svc.status === 'created';
  let sql = `UPDATE svc SET ${cols.map(c => c + '=@' + c).join(',')}`;
  if (first) sql += ', status=@st, submitted_at=@ts, expires_at=@ex, alert_ack=0';
  sql += ' WHERE id=@id';
  db.prepare(sql).run({ ...set, id: svc.id, st: 'submitted', ts: now(), ex: now() + APPROVE_WINDOW });
  log(svc.id, first ? 'submitted' : 'edited', first ? 'requester submitted the form' : 'requester edited the form');
}
function decide(svc, decision) {
  if (decision === 'accept') { db.prepare('UPDATE svc SET status=?, decided_at=? WHERE id=?').run('active', now(), svc.id); log(svc.id, 'accepted', 'transporter accepted'); }
  else { db.prepare('UPDATE svc SET status=?, decided_at=? WHERE id=?').run('denied', now(), svc.id); log(svc.id, 'denied', 'transporter denied'); }
}
function issueCode(svc) {
  const code = pad(crypto.randomInt(0, 1000000), 6);
  db.prepare("UPDATE code_challenge SET status='superseded' WHERE svc_id=? AND status='open'").run(svc.id);
  db.prepare('INSERT INTO code_challenge(svc_id,code_hmac,created_at,expires_at) VALUES (?,?,?,?)').run(svc.id, codeHmac(svc.id, code), now(), now() + CODE_VALID);
  const verb = svc.template === 'load' ? 'handed over' : 'delivered';
  sendSms(svc.id, svc.oth_phone, 'code', `Kranti code ${code} for ${svc.code}. Valid 10 minutes. Read it out to the transporter only if the goods were ${verb}.`);
  log(svc.id, 'code_requested', `code sent to ${mask(svc.oth_phone)}`);
  return code;
}
function sealWithCode(svc, code, userId) {
  const ch = db.prepare("SELECT * FROM code_challenge WHERE svc_id=? AND status='open' ORDER BY id DESC LIMIT 1").get(svc.id);
  if (!ch) throw httpErr(409, 'No code has been requested yet. Ask the other party to press "Get my code" on their page.');
  if (now() > ch.expires_at) { db.prepare("UPDATE code_challenge SET status='expired' WHERE id=?").run(ch.id); throw httpErr(409, 'That code has expired. The other party can request a new one.'); }
  if (!/^[0-9]{6}$/.test(str(code))) throw httpErr(422, 'Enter the 6-digit code.');
  if (!safeEq(codeHmac(svc.id, str(code)), ch.code_hmac)) {
    const left = MAX_WRONG - (ch.attempts + 1);
    db.prepare('UPDATE code_challenge SET attempts=attempts+1, status=? WHERE id=?').run(left <= 0 ? 'dead' : 'open', ch.id);
    log(svc.id, 'code_wrong', `wrong code entered (${left > 0 ? left + ' tries left' : 'code is dead'})`);
    throw httpErr(422, left > 0 ? `That code is not correct. ${left} ${left === 1 ? 'try' : 'tries'} left.` : 'Too many wrong tries. The other party can request a new code.');
  }
  return db.transaction(() => {
    db.prepare("UPDATE code_challenge SET status='used' WHERE id=?").run(ch.id);
    const akrn = newAkrn(), sealCode = randChars(8), t = now();
    const org = db.prepare('SELECT * FROM org WHERE id=?').get(svc.org_id);
    const ev = type => { const r = db.prepare('SELECT created_at FROM event WHERE svc_id=? AND type=? ORDER BY id LIMIT 1').get(svc.id, type); return r ? r.created_at : null; };
    const record = {
      akrn, receipt: 'GDRN', service: svc.code, template: svc.template, order_date: svc.order_date,
      transporter: { name: org.name, gstin: org.gstin },
      requester: { name: svc.req_name, gstin: svc.req_gstin, mobile: mask(svc.req_phone) },
      other_party: { role: svc.template === 'load' ? 'Seller' : 'Buyer', name: svc.oth_name, gstin: svc.oth_gstin, mobile: mask(svc.oth_phone), site: svc.oth_site },
      goods: { description: svc.goods_desc, nos: svc.goods_nos, unit: svc.goods_unit, weight: svc.goods_weight },
      windows: { lifting: [svc.lift_from, svc.lift_to], delivery: [svc.deliver_from, svc.deliver_to] },
      vehicle: svc.vehicle_no, driver: svc.driver_name, reference_receipt: svc.ref_receipt || null,
      timeline: { created: svc.created_at, submitted: svc.submitted_at, accepted: svc.decided_at, confirmation_sent: svc.confirm_sent_at, code_requested: ch.created_at, code_entered: t, sealed: t },
      evidence: { code_sent_to: mask(svc.oth_phone), entered_by_user: userId, method: 'one-time code released by the other party and entered by the transporter' },
    };
    void ev;
    const fp = sha256(canonical(record));
    db.prepare('INSERT INTO gdrn(svc_id,akrn,seal_hash,fingerprint,record,sealed_at) VALUES (?,?,?,?,?,?)').run(svc.id, akrn, sha256(sealCode), fp, JSON.stringify(record), t);
    db.prepare('UPDATE svc SET status=?, sealed_at=? WHERE id=?').run('sealed', t, svc.id);
    for (const [role, email] of [['transporter', org.email], ['requester', svc.req_email], ['other_party', svc.oth_email]])
      db.prepare('INSERT INTO email_log(svc_id,to_role,to_email,status,created_at) VALUES (?,?,?,?,?)')
        .run(svc.id, role, email || '', email ? 'recorded (demo: not actually sent)' : 'skipped: no email on file', t);
    for (const email of [org.email, svc.req_email, svc.oth_email].filter(Boolean))
      sendSms(svc.id, email, 'email', `Kranti: GDRN ${akrn} for ${svc.code} is sealed. Verify it here: ${PUBLIC_URL}/v/${akrn}/${sealCode}`);
    log(svc.id, 'sealed', `GDRN ${akrn} issued`);
    return { akrn, sealCode, fingerprint: fp };
  })();
}
function httpErr(status, message) { const e = new Error(message); e.status = status; return e; }

// ---------- seed ----------
function seed() {
  const hashPw = pw => { const salt = crypto.randomBytes(16).toString('hex'); return salt + ':' + crypto.scryptSync(pw, salt, 32).toString('hex'); };
  const valid = new Date(Date.now() + 365 * 24 * 60 * MIN).toISOString().slice(0, 10);
  const org = Number(db.prepare('INSERT INTO org(name,gstin,address,phone,email,plan,valid_until) VALUES (?,?,?,?,?,?,?)')
    .run('Demo Roadways Pvt Ltd', '08ABCDE1234F1Z5', 'Plot 14, Transport Nagar, Jaipur, Rajasthan 302013', '9811100000', 'ops@demo-roadways.test', 'Gold', valid).lastInsertRowid);
  db.prepare('INSERT INTO users(org_id,name,email,pass_hash,role) VALUES (?,?,?,?,?)').run(org, 'Adnan Khan', 'adnan@xyz.com', hashPw('Password@123'), 'owner');
  const P = db.prepare('INSERT INTO party(org_id,name,gstin,phone,address) VALUES (?,?,?,?,?)');
  const p1 = Number(P.run(org, 'Shree Balaji Enterprises', '24BBBBB1111B2Z6', '9000022222', 'Plot 7, GIDC Estate, Ahmedabad, Gujarat 382445').lastInsertRowid);
  const p2 = Number(P.run(org, 'Ganesh Agro Traders', '27AAAAA0000A1Z5', '9000033333', 'Shop 3, APMC Market, Pune, Maharashtra 411037').lastInsertRowid);
  const p3 = Number(P.run(org, 'Krishna Wholesale Mart', '29CCCCC2222C1Z3', '9000044444', 'No. 21, Market Road, Bengaluru, Karnataka 560002').lastInsertRowid);
  db.prepare('INSERT INTO driver(org_id,name,phone,licence_no) VALUES (?,?,?,?)').run(org, 'Ramesh Kumar', '9811100001', 'RJ1420230001234');
  const d2 = Number(db.prepare('INSERT INTO driver(org_id,name,phone,licence_no) VALUES (?,?,?,?)').run(org, 'Suresh Singh', '9811100002', 'RJ1420220005678').lastInsertRowid);
  const v1 = Number(db.prepare('INSERT INTO vehicle(org_id,reg_no,vtype) VALUES (?,?,?)').run(org, 'RJ14GA1234', 'Truck 16 ft').lastInsertRowid);
  db.prepare('INSERT INTO vehicle(org_id,reg_no,vtype) VALUES (?,?,?)').run(org, 'RJ14GB5678', 'Truck 22 ft');
  const d1 = 1;
  const t = todayIST(), plus = n => new Date(Date.now() + 330 * MIN + n * 86400000).toISOString().slice(0, 10);
  const sample = (other, n) => ({ req_alt_phone: '', req_email: 'accounts@requester.test', goods_desc: 'Basmati rice, 25 kg bags', goods_nos: String(n), goods_unit: 'bags', goods_weight: '',
    lift_from: t, lift_to: plus(1), deliver_from: plus(1), deliver_to: plus(4), ...other });
  // A: waiting for the requester to fill
  createOrder(org, p3, 'load', null, null);
  // B: submitted, waiting for the transporter's decision (this triggers the alert pop-up)
  const b = createOrder(org, p2, 'unload', d1, v1);
  applyRequester(view(rawSvc(b)), sample({ oth_gstin: '24BBBBB1111B2Z6', oth_name: 'Shree Balaji Enterprises', oth_address: 'Plot 7, GIDC Estate, Ahmedabad', oth_site: 'Godown 4, GIDC Estate, Ahmedabad', oth_phone: '9000055555', oth_email: '' }, 120));
  // C: accepted and active, ready for the end step
  const c = createOrder(org, p1, 'load', d1, v1);
  applyRequester(view(rawSvc(c)), sample({ oth_gstin: '27AAAAA0000A1Z5', oth_name: 'Ganesh Agro Traders', oth_address: 'Shop 3, APMC Market, Pune', oth_site: 'Warehouse 2, APMC Market, Pune', oth_phone: '9000066666', oth_email: 'ganesh@seller.test' }, 80));
  decide(view(rawSvc(c)), 'accept');
  // D: already sealed, so the verify page can be tried at once
  const d = createOrder(org, p2, 'unload', d2, v1);
  applyRequester(view(rawSvc(d)), sample({ oth_gstin: '24BBBBB1111B2Z6', oth_name: 'Shree Balaji Enterprises', oth_address: 'Plot 7, GIDC Estate, Ahmedabad', oth_site: 'Godown 4, GIDC Estate, Ahmedabad', oth_phone: '9000077777', oth_email: 'balaji@buyer.test' }, 60));
  decide(view(rawSvc(d)), 'accept');
  db.prepare('UPDATE svc SET ref_receipt=?, locked_at=?, confirm_sent_at=? WHERE id=?').run('LR-48213', now(), now(), d);
  const code = issueCode(view(rawSvc(d)));
  sealWithCode(view(rawSvc(d)), code, 1);
  db.prepare('UPDATE svc SET created_at=created_at-3600000 WHERE id=?').run(d);
}
if (fresh) { seed(); console.log('Demo data created.'); }

// ---------- web app ----------
const app = express();
app.use((req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,PUT,PATCH,DELETE,OPTIONS');
  if (req.path.startsWith('/api/')) res.setHeader('Cache-Control', 'no-store');
  if (req.method === 'OPTIONS') return res.sendStatus(204);
  next();
});
app.use(express.json({ limit: '100kb' }));
app.use(express.static(path.join(__dirname, 'public')));
const page = f => (req, res) => res.sendFile(path.join(__dirname, 'public', f));
app.get('/r/:token', page('r.html'));
app.get('/o/:token', page('o.html'));
app.get('/v/:akrn/:seal', page('v.html'));
app.get('/inbox', page('inbox.html'));
app.get('/plans', page('plans.html'));

const wrap = fn => (req, res) => { try { fn(req, res); } catch (e) { res.status(e.status || 500).json({ error: e.status ? e.message : 'Something went wrong on the server.' }); if (!e.status) console.error(e); } };

// ----- login and session -----
const sessions = new Map();
const failures = new Map();
app.post('/api/login', wrap((req, res) => {
  const email = str(req.body.email).toLowerCase();
  const f = failures.get(email);
  if (f && f.count >= 5 && now() < f.until) throw httpErr(429, 'Too many wrong passwords. Try again in a minute.');
  const u = db.prepare('SELECT * FROM users WHERE email=?').get(email);
  let ok = false;
  if (u) { const [salt, h] = u.pass_hash.split(':'); ok = safeEq(crypto.scryptSync(str(req.body.password), salt, 32).toString('hex'), h); }
  if (!ok) { const c = (f && now() < f.until ? f.count : 0) + 1; failures.set(email, { count: c, until: now() + MIN }); throw httpErr(401, 'Email or password is not correct.'); }
  failures.delete(email);
  const token = crypto.randomBytes(24).toString('hex');
  sessions.set(token, { userId: u.id, orgId: u.org_id });
  res.json({ token, now: now(), user: { id: u.id, name: u.name, email: u.email, role: u.role }, org: db.prepare('SELECT * FROM org WHERE id=?').get(u.org_id) });
}));
function auth(req, res, next) {
  const h = req.headers.authorization || '';
  const s = sessions.get(h.startsWith('Bearer ') ? h.slice(7) : '');
  if (!s) return res.status(401).json({ error: 'Please log in again.' });
  req.orgId = s.orgId; req.userId = s.userId; next();
}

// ----- demo inbox (stands in for real SMS; no login on purpose) -----
app.get('/api/demo/inbox', wrap((req, res) => {
  const phone = str(req.query.phone);
  const rows = phone ? db.prepare('SELECT * FROM sms WHERE to_phone=? ORDER BY id DESC LIMIT 100').all(phone) : db.prepare('SELECT * FROM sms ORDER BY id DESC LIMIT 100').all();
  res.json(rows);
}));

// ----- profile -----
app.get('/api/profile', auth, wrap((req, res) => {
  res.json({
    org: db.prepare('SELECT * FROM org WHERE id=?').get(req.orgId),
    parties: db.prepare('SELECT * FROM party WHERE org_id=? ORDER BY name').all(req.orgId),
    drivers: db.prepare('SELECT * FROM driver WHERE org_id=? ORDER BY name').all(req.orgId),
    vehicles: db.prepare('SELECT * FROM vehicle WHERE org_id=? ORDER BY reg_no').all(req.orgId),
  });
}));
function crud(route, table, clean) {
  app.post(`/api/${route}`, auth, wrap((req, res) => {
    const d = clean(req.body); const cols = Object.keys(d);
    try { const i = db.prepare(`INSERT INTO ${table}(org_id,${cols.join(',')}) VALUES (?,${cols.map(() => '?').join(',')})`).run(req.orgId, ...cols.map(c => d[c])); res.json({ id: Number(i.lastInsertRowid) }); }
    catch (e) { if (String(e.message).includes('UNIQUE')) throw httpErr(422, 'A requester with this GSTIN already exists in your profile.'); throw e; }
  }));
  app.put(`/api/${route}/:id`, auth, wrap((req, res) => {
    const d = clean(req.body); const cols = Object.keys(d);
    try { db.prepare(`UPDATE ${table} SET ${cols.map(c => c + '=?').join(',')} WHERE id=? AND org_id=?`).run(...cols.map(c => d[c]), req.params.id, req.orgId); res.json({ ok: true }); }
    catch (e) { if (String(e.message).includes('UNIQUE')) throw httpErr(422, 'A requester with this GSTIN already exists in your profile.'); throw e; }
  }));
  app.delete(`/api/${route}/:id`, auth, wrap((req, res) => { db.prepare(`DELETE FROM ${table} WHERE id=? AND org_id=?`).run(req.params.id, req.orgId); res.json({ ok: true }); }));
}
const firstErr = (...errs) => { const e = errs.find(Boolean); if (e) throw httpErr(422, e); };
crud('parties', 'party', b => { firstErr(reqError(b.name, 'Name'), gstinError(b.gstin), phoneError(b.phone), reqError(b.address, 'Address')); return { name: str(b.name), gstin: str(b.gstin).toUpperCase(), phone: str(b.phone), address: str(b.address) }; });
crud('drivers', 'driver', b => { firstErr(reqError(b.name, 'Driver name'), phoneError(b.phone, 'Driver mobile number')); return { name: str(b.name), phone: str(b.phone), licence_no: str(b.licence_no) }; });
crud('vehicles', 'vehicle', b => { const r = normReg(b.reg_no); firstErr(!r ? 'Vehicle number is required.' : !REG_RE.test(r) ? 'Vehicle number looks wrong. Example: RJ14GA1234.' : null); return { reg_no: r, vtype: str(b.vtype) }; });

// ----- orders (transporter) -----
const outOrder = o => { const { alert_ack, ...rest } = o; void alert_ack; return rest; };
app.get('/api/dashboard', auth, wrap((req, res) => {
  const rows = db.prepare('SELECT * FROM svc WHERE org_id=?').all(req.orgId).map(view);
  const c = { total: rows.length, created: 0, submitted: 0, active: 0, overdue: 0, dormant: 0, sealed: 0, denied: 0, expired: 0, cancelled: 0 };
  for (const o of rows) { c[o.status] = (c[o.status] || 0) + 1; if (o.flag) c[o.flag]++; }
  res.json({ counts: c, recent: rows.sort((a, b) => b.id - a.id).slice(0, 6).map(outOrder) });
}));
app.get('/api/orders', auth, wrap((req, res) => {
  res.json(db.prepare('SELECT * FROM svc WHERE org_id=? ORDER BY id DESC').all(req.orgId).map(view).map(outOrder));
}));
app.post('/api/orders', auth, wrap((req, res) => {
  const id = createOrder(req.orgId, Number(req.body.party_id), str(req.body.template), req.body.driver_id ? Number(req.body.driver_id) : null, req.body.vehicle_id ? Number(req.body.vehicle_id) : null);
  res.json(outOrder(getSvc(id, req.orgId)));
}));
app.get('/api/orders/:id', auth, wrap((req, res) => {
  const o = getSvc(req.params.id, req.orgId); if (!o) throw httpErr(404, 'Order not found.');
  const g = db.prepare('SELECT akrn, fingerprint, sealed_at FROM gdrn WHERE svc_id=?').get(o.id);
  const ch = db.prepare("SELECT * FROM code_challenge WHERE svc_id=? AND status='open' ORDER BY id DESC LIMIT 1").get(o.id);
  res.json({
    order: outOrder(o),
    events: db.prepare('SELECT type, detail, created_at FROM event WHERE svc_id=? ORDER BY id DESC').all(o.id),
    sms: db.prepare("SELECT kind, to_phone, created_at FROM sms WHERE svc_id=? AND kind!='email' ORDER BY id DESC").all(o.id).map(s => ({ kind: s.kind, to: mask(s.to_phone), created_at: s.created_at, state: 'delivered (demo)' })),
    emails: db.prepare('SELECT to_role, to_email, status FROM email_log WHERE svc_id=?').all(o.id),
    receipt: g ? { akrn: g.akrn, fingerprint: g.fingerprint, sealed_at: g.sealed_at } : null,
    code: ch && now() <= ch.expires_at ? { live_until: ch.expires_at, attempts: ch.attempts } : null,
  });
}));
const own = (req, mustBe) => {
  const o = getSvc(req.params.id, req.orgId); if (!o) throw httpErr(404, 'Order not found.');
  if (mustBe && !mustBe.includes(o.status)) throw httpErr(409, `This order is ${o.status}, so this action is not available.`);
  return o;
};
app.post('/api/orders/:id/resend', auth, wrap((req, res) => { const o = own(req, ['expired']); resendLink(o); res.json({ ok: true }); }));
app.post('/api/orders/:id/cancel', auth, wrap((req, res) => {
  const o = own(req); if (['sealed', 'cancelled'].includes(o.status)) throw httpErr(409, `A ${o.status} order cannot be cancelled.`);
  db.prepare('UPDATE svc SET status=? WHERE id=?').run('cancelled', o.id);
  db.prepare('UPDATE link SET revoked_at=? WHERE svc_id=? AND revoked_at IS NULL').run(now(), o.id);
  log(o.id, 'cancelled', 'transporter cancelled'); res.json({ ok: true });
}));
app.post('/api/orders/:id/decision', auth, wrap((req, res) => {
  const o = own(req, ['submitted']); const d = str(req.body.decision);
  if (!['accept', 'deny'].includes(d)) throw httpErr(400, 'Choose accept or deny.');
  decide(o, d); res.json({ ok: true });
}));
app.patch('/api/orders/:id/transport', auth, wrap((req, res) => {
  const o = own(req, ['created', 'submitted', 'active']);
  if (o.locked_at) throw httpErr(409, 'Driver and vehicle are locked once the reference receipt is recorded or the confirmation is sent.');
  const d = req.body.driver_id ? db.prepare('SELECT * FROM driver WHERE id=? AND org_id=?').get(req.body.driver_id, req.orgId) : null;
  const v = req.body.vehicle_id ? db.prepare('SELECT * FROM vehicle WHERE id=? AND org_id=?').get(req.body.vehicle_id, req.orgId) : null;
  db.prepare('UPDATE svc SET driver_id=?, driver_name=?, driver_phone=?, vehicle_no=?, vehicle_type=? WHERE id=?')
    .run(d ? d.id : null, d ? d.name : null, d ? d.phone : null, v ? v.reg_no : null, v ? v.vtype : null, o.id);
  log(o.id, 'transport_set', `driver ${d ? d.name : '-'}, vehicle ${v ? v.reg_no : '-'}`); res.json({ ok: true });
}));
app.post('/api/orders/:id/reference', auth, wrap((req, res) => {
  const o = own(req, ['active']); const r = str(req.body.ref_receipt);
  if (!r) throw httpErr(422, 'Enter the reference receipt number.'); if (r.length > 40) throw httpErr(422, 'Reference receipt number must be at most 40 characters.');
  if (!o.driver_id || !o.vehicle_no) throw httpErr(422, 'Add the driver and the vehicle first. They lock when the reference receipt is recorded.');
  db.prepare('UPDATE svc SET ref_receipt=?, locked_at=? WHERE id=?').run(r, now(), o.id); log(o.id, 'reference', `reference receipt ${r} recorded`); res.json({ ok: true });
}));
app.patch('/api/orders/:id/other-email', auth, wrap((req, res) => {
  const o = own(req, ['created', 'submitted', 'active']); const e = emailError(req.body.email, 'Email', true); if (e) throw httpErr(422, e);
  db.prepare('UPDATE svc SET oth_email=? WHERE id=?').run(str(req.body.email), o.id); log(o.id, 'other_email', 'other party email updated'); res.json({ ok: true });
}));
app.post('/api/orders/:id/send-confirm', auth, wrap((req, res) => {
  const o = own(req, ['active']); if (o.flag === 'dormant') throw httpErr(409, 'This order is dormant. It cannot go to confirmation.');
  if (!o.driver_id || !o.vehicle_no) throw httpErr(422, 'Add the driver and the vehicle before sending for confirmation.');
  const org = db.prepare('SELECT * FROM org WHERE id=?').get(o.org_id);
  const token = newLink(o.id, 'other', CONFIRM_LINK_WINDOW);
  db.prepare('UPDATE svc SET confirm_sent_at=?, locked_at=COALESCE(locked_at, ?) WHERE id=?').run(now(), now(), o.id);
  sendSms(o.id, o.oth_phone, 'link-other', `Kranti: ${org.name} (transporter) asks you to confirm the handover for ${o.code}. Open: ${PUBLIC_URL}/o/${token}`);
  log(o.id, 'confirm_sent', `confirmation link sent to ${mask(o.oth_phone)}`); res.json({ ok: true });
}));
app.post('/api/orders/:id/seal', auth, wrap((req, res) => {
  const o = own(req, ['active']); if (o.flag === 'dormant') throw httpErr(409, 'This order is dormant. It cannot be sealed.');
  const s = sealWithCode(o, req.body.code, req.userId);
  res.json({ ok: true, akrn: s.akrn, fingerprint: s.fingerprint, verify_path: `/v/${s.akrn}/${s.sealCode}` });
}));
app.get('/api/alerts', auth, wrap((req, res) => {
  res.json(db.prepare("SELECT id, code, template, req_name, expires_at FROM svc WHERE org_id=? AND status='submitted' AND alert_ack=0 AND expires_at>?").all(req.orgId, now()));
}));
app.post('/api/alerts/:id/ack', auth, wrap((req, res) => { db.prepare('UPDATE svc SET alert_ack=1 WHERE id=? AND org_id=?').run(req.params.id, req.orgId); res.json({ ok: true }); }));

// ----- public pages: requester (/r), other party (/o), verify (/v). Uniform errors. -----
const BAD_LINK = 'This link is not valid or has expired.';
const publicBase = (o, org) => ({
  code: o.code, template: o.template, status: o.status, flag: o.flag, now: now(), expires_at: o.expires_at,
  transporter: { name: org.name, gstin: org.gstin, phone: mask(org.phone) },
  labels: { other_role: o.template === 'load' ? 'Seller' : 'Buyer', site: o.template === 'load' ? 'Pick-up (load) address' : 'Drop (unload) address' },
});
function reqLink(req) { const l = findLink(req.params.token, 'requester'); if (!l) throw httpErr(404, BAD_LINK); return view(rawSvc(l.svc_id)); }
app.get('/api/public/r/:token', wrap((req, res) => {
  const o = reqLink(req); const org = db.prepare('SELECT * FROM org WHERE id=?').get(o.org_id);
  const editable = ['created', 'submitted'].includes(o.status);
  const fields = {}; for (const k of ALL_FIELDS) fields[k] = o[k] === null || o[k] === undefined ? '' : String(o[k]);
  res.json({ ...publicBase(o, org), editable, requester: { name: o.req_name, gstin: o.req_gstin, phone: mask(o.req_phone), address: o.req_address }, order_date: o.order_date, fields, submitted: !!o.submitted_at });
}));
app.post('/api/public/r/:token/seen', wrap((req, res) => { const o = reqLink(req); if (!db.prepare("SELECT 1 FROM event WHERE svc_id=? AND type='requester_opened'").get(o.id)) log(o.id, 'requester_opened', 'link opened in a browser'); res.json({ ok: true }); }));
app.post('/api/public/r/:token/validate', wrap((req, res) => {
  const o = reqLink(req); const sec = SECTION_FIELDS[str(req.body.section)]; if (!sec) throw httpErr(400, 'Unknown section.');
  res.json({ errors: validateRequester(req.body.fields || {}, o, sec) });
}));
app.post('/api/public/r/:token/submit', wrap((req, res) => {
  const o = reqLink(req);
  if (o.status === 'expired') throw httpErr(410, 'This request has expired. Ask the transporter to send a new link.');
  if (!['created', 'submitted'].includes(o.status)) throw httpErr(409, 'The transporter has already decided, so the form can no longer be edited.');
  const errors = validateRequester(req.body.fields || {}, o, null);
  if (Object.keys(errors).length) return res.status(422).json({ error: 'Please fix the highlighted fields.', errors });
  applyRequester(o, req.body.fields); res.json({ ok: true });
}));
function othLink(req) { const l = findLink(req.params.token, 'other'); if (!l || now() > l.expires_at) throw httpErr(404, BAD_LINK); return view(rawSvc(l.svc_id)); }
function otherState(o) {
  const last = db.prepare('SELECT * FROM code_challenge WHERE svc_id=? ORDER BY id DESC LIMIT 1').get(o.id);
  const g = db.prepare('SELECT akrn FROM gdrn WHERE svc_id=?').get(o.id);
  return { code_requested: !!last && last.status === 'open' && now() <= last.expires_at, can_request_at: last ? last.created_at + CODE_COOLDOWN : 0, code_expires_at: last ? last.expires_at : 0, sealed: !!g };
}
app.get('/api/public/o/:token', wrap((req, res) => {
  const o = othLink(req); const org = db.prepare('SELECT * FROM org WHERE id=?').get(o.org_id);
  res.json({ ...publicBase(o, org), ...otherState(o), sent_to: mask(o.oth_phone),
    requester: { name: o.req_name, gstin: o.req_gstin }, other: { name: o.oth_name, gstin: o.oth_gstin },
    goods: { description: o.goods_desc, nos: o.goods_nos, unit: o.goods_unit, weight: o.goods_weight },
    windows: { lift_from: o.lift_from, lift_to: o.lift_to, deliver_from: o.deliver_from, deliver_to: o.deliver_to },
    transport: { vehicle: o.vehicle_no, vehicle_type: o.vehicle_type, driver: o.driver_name, reference_receipt: o.ref_receipt },
    order_date: o.order_date });
}));
app.post('/api/public/o/:token/seen', wrap((req, res) => { const o = othLink(req); if (!db.prepare("SELECT 1 FROM event WHERE svc_id=? AND type='other_opened'").get(o.id)) log(o.id, 'other_opened', 'link opened in a browser'); res.json({ ok: true }); }));
app.post('/api/public/o/:token/code', wrap((req, res) => {
  const o = othLink(req);
  if (o.status !== 'active' || o.flag === 'dormant') throw httpErr(409, 'This order is not ready for a code.');
  const recent = db.prepare('SELECT created_at FROM code_challenge WHERE svc_id=? ORDER BY id DESC LIMIT 1').get(o.id);
  if (recent && now() < recent.created_at + CODE_COOLDOWN) throw httpErr(429, `Please wait ${Math.ceil((recent.created_at + CODE_COOLDOWN - now()) / 1000)} seconds before asking for another code.`);
  if (db.prepare('SELECT COUNT(*) n FROM code_challenge WHERE svc_id=? AND created_at>?').get(o.id, now() - 60 * MIN).n >= CODES_PER_HOUR) throw httpErr(429, 'You have asked for 5 codes in the last hour. Please try again later.');
  issueCode(o); res.json({ ok: true, sent_to: mask(o.oth_phone), expires_at: now() + CODE_VALID, can_request_at: now() + CODE_COOLDOWN });
}));
app.get('/api/public/v/:akrn/:seal', wrap((req, res) => {
  const g = db.prepare('SELECT * FROM gdrn WHERE akrn=?').get(req.params.akrn);
  if (!g || !safeEq(g.seal_hash, sha256(req.params.seal))) throw httpErr(404, 'No receipt matches this address.');
  const record = JSON.parse(g.record); const fp = sha256(canonical(record)); const f = str(req.query.f);
  res.json({ record, fingerprint: g.fingerprint, matches: fp === g.fingerprint, link_check: f ? g.fingerprint.startsWith(f) : null, sealed_at: g.sealed_at });
}));
app.use('/api', (req, res) => res.status(404).json({ error: 'Not found.' }));

app.listen(PORT, () => {
  console.log('');
  console.log('  Kranti transport prototype server is running.');
  console.log(`  Open this in your browser: ${PUBLIC_URL}`);
  console.log(`  Demo phone inbox:          ${PUBLIC_URL}/inbox`);
  console.log('  Demo login: adnan@xyz.com / Password@123');
  console.log('');
});
