// 应用状态、与服务端的同步、以及所有写操作。
import * as D from '../shared/domain.js';
import { foodMap, CATEGORY_BY_ID, FIBER_BOOSTERS } from '../shared/foods.js';

const PREF_DEFAULTS = { appearance: 'system', autoDark20: false, emojiSize: 28, hand: 'right', haptics: true, ack: false, range: 30, excludeOutliers: true };
function readPrefs() {
  try { return { ...PREF_DEFAULTS, ...JSON.parse(localStorage.getItem('prefs') || '{}') }; } catch { return { ...PREF_DEFAULTS }; }
}

export const S = { data: null, today: D.logicalDay(), day: null, tab: 'today', prefs: readPrefs(), onError: null };

const listeners = [];
export const onChange = (fn) => listeners.push(fn);
export const refresh = () => listeners.forEach((fn) => fn());

export function setPrefs(patch) {
  S.prefs = { ...S.prefs, ...patch };
  try { localStorage.setItem('prefs', JSON.stringify(S.prefs)); } catch { /* 隐私模式下只在本次会话生效 */ }
  applyTheme();
  refresh();
}

const mql = window.matchMedia('(prefers-color-scheme: dark)');
mql.addEventListener('change', applyTheme);
export function applyTheme() {
  const p = S.prefs, hour = new Date().getHours();
  const dark = p.appearance === 'dark' || (p.appearance === 'system' && (mql.matches || (p.autoDark20 && (hour >= 20 || hour < 6))));
  document.documentElement.dataset.theme = dark ? 'dark' : 'light';
  document.documentElement.style.setProperty('--emoji-size', `${p.emojiSize / 16}rem`);
  document.documentElement.dataset.hand = p.hand;
  // 应用内可以覆盖系统外观，状态栏颜色跟着页面顶部的背景色走
  document.querySelectorAll('meta[name="theme-color"]').forEach((m) => { m.content = dark ? '#1C1C1E' : '#F2F2F7'; });
}

async function request(url, body) {
  const r = await fetch(url, body ? { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) } : undefined);
  if (!r.ok) throw new Error((await r.json().catch(() => ({}))).error || `请求失败（${r.status}）`);
  return r.json();
}

export async function load() {
  const was = S.today;
  S.today = D.logicalDay();
  if (!S.day || S.day > S.today || S.day === was) S.day = S.today;
  let data = await request('api/state');
  if (data.settings.demo && data.settings.demoAnchor !== S.today) data = await request('api/demo/sync', { today: S.today });
  S.data = data;
}

export async function resetData(mode) {
  await chain;
  S.data = await request('api/reset', { mode, today: S.today });
  S.day = S.today;
  refresh();
}

function applyLocal(o) {
  if (o.collection === 'settings') { if (o.op === 'put') S.data.settings = o.doc; return; }
  const arr = S.data[o.collection];
  const id = o.op === 'put' ? o.doc.id : o.id;
  const i = arr.findIndex((x) => x.id === id);
  if (o.op === 'put') { if (i >= 0) arr[i] = o.doc; else arr.push(o.doc); } else if (i >= 0) arr.splice(i, 1);
}

// 乐观更新：先改本地，再按顺序写到服务端；失败则重新载入
let chain = Promise.resolve();
export function commit(ops) {
  ops.forEach(applyLocal);
  chain = chain.then(() => request('api/batch', { ops })).catch(async (e) => {
    S.onError?.(e);
    try { await load(); refresh(); } catch { /* 下次操作再试 */ }
  });
  return chain;
}

const put = (collection, doc) => ({ op: 'put', collection, doc });
const del = (collection, id) => ({ op: 'del', collection, id });
const uid = (p) => `${p}_${Date.now().toString(36)}${Math.random().toString(36).slice(2, 7)}`;

// ---------- 派生 ----------
let foodsKey = null, foodsCache = null;
export function foods() {
  const key = JSON.stringify(S.data.settings.servingOverrides || {});
  if (key !== foodsKey) { foodsKey = key; foodsCache = foodMap(S.data.settings.servingOverrides || {}); }
  return foodsCache;
}
export const outliers = () => new Set(S.data.dayMeta.filter((m) => m.isOutlier).map((m) => m.day));

export function dayContext(day) {
  const F = foods(), entries = S.data.entries, out = outliers();
  const dayEntries = entries.filter((e) => e.day === day).sort((a, b) => a.createdAt.localeCompare(b.createdAt));
  const spend = D.dailySpend(dayEntries, F);
  const mode = S.data.settings.budgetMode;
  const weekly = D.weeklyCounts(entries, F, S.data.limits, day);
  const base = D.baseline(D.totalsByDay(entries, F), out, day);
  const from = D.addDays(day, -7);
  const recentKeys = new Set(S.data.adviceLog.filter((a) => a.day < day && a.day >= from).map((a) => a.key));
  const isOutlier = out.has(day);
  const advice = D.advise({ spend, mode, weekly, isOutlier, recentKeys, foods: F, categories: CATEGORY_BY_ID, boosters: FIBER_BOOSTERS });
  const complete = D.MAIN_MEALS.every((m) => dayEntries.some((e) => e.meal === m));
  return { day, dayEntries, spend, mode, budget: D.satBudget(mode), weekly, base, isOutlier, advice, complete };
}

// ---------- 写操作 ----------
export function addEntry({ day, meal, food, servingLabel, multiplier, source }) {
  const serving = food.servings.find((x) => x.label === servingLabel) || food.servings[food.defaultServing];
  const e = { id: uid('entry'), day, meal, foodId: food.id, servingLabel: serving.label, multiplier, grams: serving.grams * multiplier, photoRef: null, source, createdAt: new Date().toISOString() };
  const m = D.mergeEntry(S.data.entries, e);
  commit([put('entries', m.entry)]);
  return { merged: m.merged, entry: m.entry, undo: () => { commit([m.merged ? put('entries', m.previous) : del('entries', e.id)]); refresh(); } };
}

export function updateEntry(entry, { meal, servingLabel, multiplier }, food) {
  const serving = food.servings.find((x) => x.label === servingLabel) || food.servings[food.defaultServing];
  const next = { ...entry, meal, servingLabel: serving.label, multiplier, grams: serving.grams * multiplier };
  const others = S.data.entries.filter((x) => x.id !== entry.id);
  const m = D.mergeEntry(others, next);
  commit(m.merged ? [del('entries', entry.id), put('entries', m.entry)] : [put('entries', next)]);
}

export function deleteEntry(entry) {
  commit([del('entries', entry.id)]);
  return () => { commit([put('entries', entry)]); refresh(); };
}

export function toggleOutlier(day) {
  const on = !outliers().has(day);
  commit([put('dayMeta', { id: day, day, isOutlier: on })]);
  return on;
}

export const setSettings = (patch) => commit([put('settings', { ...S.data.settings, ...patch })]);

export function saveAdvice(day, key) {
  const cur = S.data.adviceLog.find((a) => a.id === day);
  if (cur?.key === key) return;
  commit([key ? put('adviceLog', { id: day, day, key }) : del('adviceLog', day)]);
}

export const sortedOneTouch = () => [...S.data.oneTouch].sort((a, b) => a.sortOrder - b.sortOrder);
export function addOneTouch({ foodId, servingLabel, multiplier, meal }) {
  const list = S.data.oneTouch;
  if (list.some((o) => o.foodId === foodId && o.servingLabel === servingLabel && o.multiplier === multiplier && o.meal === meal)) return 'exists';
  if (list.length >= D.MAX_ONE_TOUCH) return 'full';
  commit([put('oneTouch', { id: uid('ot'), foodId, servingLabel, multiplier, meal, sortOrder: Math.max(-1, ...list.map((o) => o.sortOrder)) + 1 })]);
  return 'ok';
}
export const removeOneTouch = (id) => commit([del('oneTouch', id)]);
export function moveOneTouchUp(id) {
  const list = sortedOneTouch(), i = list.findIndex((o) => o.id === id);
  if (i <= 0) return;
  const a = list[i - 1], b = list[i];
  commit([put('oneTouch', { ...a, sortOrder: b.sortOrder }), put('oneTouch', { ...b, sortOrder: a.sortOrder })]);
}

export const saveLimit = (limit) => commit([put('limits', limit.id ? limit : { ...limit, id: uid('limit'), period: 'week' })]);
export const removeLimit = (id) => commit([del('limits', id)]);

export const saveLab = (lab) => commit([put('labs', lab.id ? lab : { ...lab, id: uid('lab'), unit: 'mmol/L' })]);
export const removeLab = (id) => commit([del('labs', id)]);

export function setServingOverride(foodId, label, grams) {
  const all = { ...(S.data.settings.servingOverrides || {}) };
  const one = { ...(all[foodId] || {}) };
  if (grams > 0) one[label] = grams; else delete one[label];
  if (Object.keys(one).length) all[foodId] = one; else delete all[foodId];
  return setSettings({ servingOverrides: all });
}
