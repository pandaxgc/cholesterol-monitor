import http from 'node:http';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { DatabaseSync } from 'node:sqlite';
import { foodMap, DEFAULT_LIMITS } from './shared/foods.js';
import { addDays } from './shared/domain.js';
import { demoDay, demoLabs, DEMO_ONE_TOUCH, DEMO_DAYS } from './shared/demo.js';

const ROOT = path.dirname(fileURLToPath(import.meta.url));
const PORT = Number(process.env.PORT) || 3000;
// 数据放在应用目录之外，重新部署或回滚不会丢失
const DATA_DIR = process.env.DATA_DIR || path.join(os.homedir(), 'app-prd-data');
fs.mkdirSync(DATA_DIR, { recursive: true });

const db = new DatabaseSync(path.join(DATA_DIR, 'app.db'));
db.exec(`PRAGMA journal_mode = WAL;
CREATE TABLE IF NOT EXISTS docs (collection TEXT NOT NULL, id TEXT NOT NULL, json TEXT NOT NULL, PRIMARY KEY (collection, id));`);

const COLLECTIONS = ['entries', 'oneTouch', 'limits', 'dayMeta', 'labs', 'adviceLog', 'settings'];
const ID_RE = /^[\w.:|-]{1,96}$/;
const DAY_RE = /^\d{4}-\d{2}-\d{2}$/;
const DEFAULT_SETTINGS = { id: 'main', budgetMode: 'standard', reminderTime: '21:30', demo: true, demoAnchor: null, servingOverrides: {} };

const qPut = db.prepare('INSERT INTO docs (collection, id, json) VALUES (?, ?, ?) ON CONFLICT (collection, id) DO UPDATE SET json = excluded.json');
const qDel = db.prepare('DELETE FROM docs WHERE collection = ? AND id = ?');
const qAll = db.prepare('SELECT json FROM docs WHERE collection = ?');
const qGet = db.prepare('SELECT json FROM docs WHERE collection = ? AND id = ?');
const qClear = db.prepare('DELETE FROM docs WHERE collection = ?');
const qDays = db.prepare("SELECT DISTINCT json_extract(json, '$.day') AS day, json_extract(json, '$.meal') AS meal FROM docs WHERE collection = 'entries'");

const put = (collection, doc) => qPut.run(collection, doc.id, JSON.stringify(doc));
const all = (collection) => qAll.all(collection).map((r) => JSON.parse(r.json));
const getSettings = () => { const r = qGet.get('settings', 'main'); return r ? JSON.parse(r.json) : null; };
function tx(fn) {
  db.exec('BEGIN');
  try { const r = fn(); db.exec('COMMIT'); return r; } catch (e) { db.exec('ROLLBACK'); throw e; }
}

if (!getSettings()) tx(() => { put('settings', DEFAULT_SETTINGS); DEFAULT_LIMITS.forEach((l) => put('limits', l)); });

function state() {
  const s = {};
  for (const c of COLLECTIONS) s[c] = all(c);
  s.settings = s.settings.find((x) => x.id === 'main') || DEFAULT_SETTINGS;
  return s;
}

// 示例数据：首次生成 90 天；之后每次打开把缺的日子补齐，已有记录的日子不动
function syncDemo(today) {
  const settings = getSettings();
  if (!settings?.demo || settings.demoAnchor === today) return false;
  const foods = foodMap();
  const have = new Map();
  for (const r of qDays.all()) { if (!have.has(r.day)) have.set(r.day, new Set()); have.get(r.day).add(r.meal); }
  const write = (day, mode) => {
    const { entries, outlier } = demoDay(day, foods, mode);
    entries.forEach((e) => put('entries', e));
    if (outlier) put('dayMeta', { id: day, day, isOutlier: true, demo: true });
  };
  tx(() => {
    const anchor = settings.demoAnchor;
    if (!anchor) {
      for (let i = DEMO_DAYS; i >= 1; i--) write(addDays(today, -i), 'full');
      demoLabs(today).forEach((l) => put('labs', l));
      DEMO_ONE_TOUCH.forEach((o) => put('oneTouch', o));
    } else if (anchor < today) {
      const start = addDays(today, -DEMO_DAYS) > anchor ? addDays(today, -DEMO_DAYS) : anchor;
      for (let d = start; d < today; d = addDays(d, 1)) {
        const meals = have.get(d);
        if (!meals) write(d, 'full');
        else if (d === anchor && !meals.has('dinner')) write(d, 'rest');
      }
    }
    if (!have.has(today)) write(today, 'partial');
    put('settings', { ...settings, demoAnchor: today });
  });
  return true;
}

function reset(mode, today) {
  tx(() => {
    for (const c of ['entries', 'oneTouch', 'dayMeta', 'labs', 'adviceLog', 'limits']) qClear.run(c);
    DEFAULT_LIMITS.forEach((l) => put('limits', l));
    const prev = getSettings() || DEFAULT_SETTINGS;
    put('settings', { ...prev, demo: mode === 'demo', demoAnchor: null, servingOverrides: {} });
  });
  if (mode === 'demo') syncDemo(today);
}

function applyOps(ops) {
  if (!Array.isArray(ops) || ops.length > 500) throw new HttpError(400, 'ops 无效');
  tx(() => {
    for (const o of ops) {
      if (!COLLECTIONS.includes(o.collection)) throw new HttpError(400, '未知集合');
      const id = o.op === 'put' ? o.doc?.id : o.id;
      if (typeof id !== 'string' || !ID_RE.test(id)) throw new HttpError(400, 'id 无效');
      if (o.op === 'put') put(o.collection, o.doc);
      else if (o.op === 'del') qDel.run(o.collection, id);
      else throw new HttpError(400, '未知操作');
    }
  });
}

class HttpError extends Error { constructor(status, message) { super(message); this.status = status; } }

function readJson(req) {
  return new Promise((resolve, reject) => {
    let size = 0; const chunks = [];
    req.on('data', (c) => { size += c.length; if (size > 512 * 1024) { reject(new HttpError(413, '请求过大')); req.destroy(); } else chunks.push(c); });
    req.on('end', () => { try { resolve(chunks.length ? JSON.parse(Buffer.concat(chunks).toString('utf8')) : {}); } catch { reject(new HttpError(400, 'JSON 无效')); } });
    req.on('error', reject);
  });
}

const TYPES = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.css': 'text/css; charset=utf-8', '.svg': 'image/svg+xml', '.png': 'image/png', '.json': 'application/json; charset=utf-8', '.ico': 'image/x-icon', '.webmanifest': 'application/manifest+json; charset=utf-8' };

function serveStatic(pathname, res) {
  let base = path.join(ROOT, 'public'), rel = pathname;
  if (pathname.startsWith('/shared/')) { base = path.join(ROOT, 'shared'); rel = pathname.slice('/shared'.length); }
  if (rel === '/' || rel === '') rel = '/index.html';
  const file = path.normalize(path.join(base, rel));
  if (!file.startsWith(base + path.sep)) throw new HttpError(403, 'forbidden');
  if (!fs.existsSync(file) || !fs.statSync(file).isFile()) throw new HttpError(404, 'not found');
  res.writeHead(200, { 'Content-Type': TYPES[path.extname(file)] || 'application/octet-stream', 'Cache-Control': 'no-cache' });
  fs.createReadStream(file).pipe(res);
}

const sendJson = (res, status, body) => { res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' }); res.end(JSON.stringify(body)); };

const server = http.createServer(async (req, res) => {
  try {
    const { pathname } = new URL(req.url, 'http://localhost');
    if (pathname === '/api/state' && req.method === 'GET') return sendJson(res, 200, state());
    if (pathname.startsWith('/api/') && req.method === 'POST') {
      const body = await readJson(req);
      if (pathname === '/api/batch') { applyOps(body.ops); return sendJson(res, 200, { ok: true }); }
      if (pathname === '/api/demo/sync' || pathname === '/api/reset') {
        if (!DAY_RE.test(body.today || '')) throw new HttpError(400, 'today 无效');
        if (pathname === '/api/reset') {
          if (!['demo', 'blank'].includes(body.mode)) throw new HttpError(400, 'mode 无效');
          reset(body.mode, body.today);
        } else syncDemo(body.today);
        return sendJson(res, 200, state());
      }
    }
    if (pathname.startsWith('/api/')) throw new HttpError(404, 'not found');
    if (req.method !== 'GET' && req.method !== 'HEAD') throw new HttpError(405, 'method not allowed');
    serveStatic(decodeURIComponent(pathname), res);
  } catch (e) {
    if (!(e instanceof HttpError)) console.error(e);
    if (!res.headersSent) sendJson(res, e.status || 500, { error: e.status ? e.message : '服务器错误' });
    else res.end();
  }
});

server.listen(PORT, () => console.log(`app-prd listening on :${PORT} (data: ${DATA_DIR})`));
