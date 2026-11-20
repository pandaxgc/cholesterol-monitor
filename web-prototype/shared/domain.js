// 领域逻辑：全部为纯函数，不依赖 UI 与存储（PRD §7.3、§8、§3.5）。

export const MEALS = ['breakfast', 'lunch', 'dinner', 'snack'];
export const MAIN_MEALS = ['breakfast', 'lunch', 'dinner'];
export const MEAL_LABEL = { breakfast: '早餐', lunch: '午餐', dinner: '晚餐', snack: '加餐' };
export const BUDGET = { satStandard: 22, satStrict: 11, cholMg: 300, fiberG: 10, transMaxG: 2 };
export const GRADE_LABEL = { A: '友好', B: '适量', C: '留意' };
export const MAX_ONE_TOUCH = 12;

export const satBudget = (mode) => (mode === 'strict' ? BUDGET.satStrict : BUDGET.satStandard);

// ---------- 日期 ----------
const pad = (n) => String(n).padStart(2, '0');
const toUTC = (day) => { const [y, m, d] = day.split('-').map(Number); return Date.UTC(y, m - 1, d); };
const fromUTC = (ms) => { const t = new Date(ms); return `${t.getUTCFullYear()}-${pad(t.getUTCMonth() + 1)}-${pad(t.getUTCDate())}`; };

// 04:00 之前的记录归属前一天
export function logicalDay(date = new Date(), cutoffHour = 4) {
  const t = new Date(date.getTime() - cutoffHour * 3600e3);
  return `${t.getFullYear()}-${pad(t.getMonth() + 1)}-${pad(t.getDate())}`;
}
export const addDays = (day, n) => fromUTC(toUTC(day) + n * 864e5);
export const diffDays = (a, b) => Math.round((toUTC(a) - toUTC(b)) / 864e5);
export const weekday = (day) => new Date(toUTC(day)).getUTCDay();
export const weekStart = (day) => addDays(day, -((weekday(day) + 6) % 7));
export const dayLabel = (day) => { const [, m, d] = day.split('-').map(Number); return `${m}月${d}日`; };
export const dayRange = (end, n) => Array.from({ length: n }, (_, i) => addDays(end, i - n + 1));

// ---------- 分级 ----------
export function gradeOf(n) {
  if (n.satFatG >= 5 || n.transFatG > 0.1 || n.cholesterolMg >= 100) return 'C';
  if (n.satFatG >= 2) return 'B';
  return 'A';
}

// ---------- 显示精度 ----------
export const fmtSat = (g) => `约 ${Math.round(g)} g`;
export const fmtChol = (mg) => `约 ${Math.round(mg / 10) * 10} mg`;
export const fmtFiber = (g) => `约 ${Math.round(g)} g`;
export const transLabel = (g) => (g > 0 ? '含反式脂肪' : '不含反式脂肪');
export const roundPct5 = (ratio) => Math.round(ratio * 20) * 5;

const CN = ['零', '一', '两', '三', '四', '五', '六', '七', '八', '九'];
export function shareWords(ratio) {
  if (ratio >= 0.95) return '几乎全部';
  const t = Math.round(ratio * 10);
  if (t <= 0) return '不到一成';
  if (t === 5) return '一半';
  return `${CN[t]}成`;
}
export function diffWords(value, base) {
  if (!(base > 0)) return null;
  const r = (value - base) / base;
  const a = Math.abs(r);
  if (a < 0.05) return '和你平时差不多';
  if (r >= 0.95) return `约为你平时的 ${Math.round(value / base)} 倍`;
  if (r <= -0.95) return '比你平时少九成以上';
  return `比你平时${r > 0 ? '多' : '少'}${shareWords(a)}`;
}

export function servingText(entry) {
  const m = entry.multiplier;
  const ms = Number.isInteger(m) ? String(m) : m === 0.5 ? '½' : String(Math.round(m * 100) / 100);
  if ([...entry.servingLabel].length === 1) return m === 0.5 ? `半${entry.servingLabel}` : `${ms} ${entry.servingLabel}`;
  return m === 1 ? entry.servingLabel : `${entry.servingLabel} ×${ms}`;
}

// ---------- 聚合 ----------
const zero = () => ({ sat: 0, trans: 0, chol: 0, fiber: 0 });
const acc = (a, b) => { a.sat += b.sat; a.trans += b.trans; a.chol += b.chol; a.fiber += b.fiber; return a; };

export function nutritionOf(entry, food) {
  const k = entry.grams / 100, n = food.nutritionPer100g;
  return { sat: n.satFatG * k, trans: n.transFatG * k, chol: n.cholesterolMg * k, fiber: n.solubleFiberG * k };
}

// DailySpend：某日四项合计、各餐小计
export function dailySpend(dayEntries, foods) {
  const total = zero(), meals = {}, items = [];
  for (const m of MEALS) meals[m] = zero();
  for (const entry of dayEntries) {
    const food = foods.get(entry.foodId);
    if (!food) continue;
    const n = nutritionOf(entry, food);
    acc(total, n); acc(meals[entry.meal] || (meals[entry.meal] = zero()), n);
    items.push({ entry, food, n });
  }
  return { total, meals, items };
}

export const balance = (mode, sat) => satBudget(mode) - sat;

export function totalsByDay(entries, foods) {
  const m = new Map();
  for (const e of entries) {
    const food = foods.get(e.foodId);
    if (!food) continue;
    if (!m.has(e.day)) m.set(e.day, zero());
    acc(m.get(e.day), nutritionOf(e, food));
  }
  return m;
}

// Baseline：beforeDay 之前最近 14 个非离群记录日的均值；不足 5 天返回 null
export function baseline(totals, outliers, beforeDay, { window = 14, minDays = 5 } = {}) {
  const days = [...totals.keys()].filter((d) => d < beforeDay && !outliers.has(d)).sort().slice(-window);
  if (days.length < minDays) return null;
  const sum = zero();
  for (const d of days) acc(sum, totals.get(d));
  const n = days.length;
  return { sat: sum.sat / n, trans: sum.trans / n, chol: sum.chol / n, fiber: sum.fiber / n, days: n };
}

// WeeklyCount：自然周（周一至周日）内各限额类别次数，同一餐同一类别计 1 次
export function weeklyCounts(entries, foods, limits, day) {
  const ws = weekStart(day), we = addDays(ws, 6);
  return limits.map((limit) => {
    const seen = new Set();
    for (const e of entries) {
      if (e.day < ws || e.day > we) continue;
      if (foods.get(e.foodId)?.category === limit.category) seen.add(`${e.day}|${e.meal}`);
    }
    return { limit, count: seen.size, reached: seen.size >= limit.maxCount, over: seen.size > limit.maxCount };
  });
}

// SourceRanking：按类别累计饱和脂肪排序
export function sourceRanking(entries, foods) {
  const by = new Map();
  let total = 0;
  for (const e of entries) {
    const food = foods.get(e.foodId);
    if (!food) continue;
    const sat = nutritionOf(e, food).sat;
    by.set(food.category, (by.get(food.category) || 0) + sat);
    total += sat;
  }
  return [...by].map(([category, sat]) => ({ category, sat, share: total ? sat / total : 0 })).sort((a, b) => b.sat - a.sat);
}

// HeatLevel：按用户自身分布的五分位分档（1–5），无记录为 0
export function heatThresholds(values) {
  const v = values.filter((x) => x > 0).sort((a, b) => a - b);
  if (!v.length) return [];
  const q = (p) => v[Math.min(v.length - 1, Math.floor(p * v.length))];
  return [q(0.2), q(0.4), q(0.6), q(0.8)];
}
export function heatLevel(value, thresholds) {
  if (!(value > 0) || !thresholds.length) return 0;
  let level = 1;
  for (const t of thresholds) if (value >= t) level++;
  return Math.min(level, 5);
}

// ---------- 记录 ----------
// 同餐次同食物再次添加时合并份量
export function mergeEntry(entries, e) {
  const hit = entries.find((x) => x.day === e.day && x.meal === e.meal && x.foodId === e.foodId);
  if (!hit) return { merged: false, entry: e, previous: null };
  const unit = hit.grams / hit.multiplier;
  const grams = hit.grams + e.grams;
  return { merged: true, previous: hit, entry: { ...hit, grams, multiplier: Math.round((grams / unit) * 100) / 100 } };
}

export function lastServing(entries, foodId) {
  let last = null;
  for (const e of entries) if (e.foodId === foodId && (!last || e.createdAt > last.createdAt)) last = e;
  return last ? { servingLabel: last.servingLabel, multiplier: last.multiplier } : null;
}

// 按习惯预填：最近 14 个记过该餐的日子里，出现率不低于一半的食物（最多 3 个）
export function prefillFor(entries, day, meal, { window = 14, minDays = 3, max = 3 } = {}) {
  const byDay = new Map();
  for (const e of entries) {
    if (e.meal !== meal || e.day >= day) continue;
    if (!byDay.has(e.day)) byDay.set(e.day, []);
    byDay.get(e.day).push(e);
  }
  const days = [...byDay.keys()].sort().slice(-window);
  if (days.length < minDays) return [];
  const stat = new Map();
  for (const d of days) {
    for (const e of byDay.get(d)) {
      const s = stat.get(e.foodId) || { count: 0, last: null };
      s.count++; s.last = e; stat.set(e.foodId, s);
    }
  }
  return [...stat].filter(([, s]) => s.count / days.length >= 0.5)
    .sort((a, b) => b[1].count - a[1].count).slice(0, max)
    .map(([foodId, s]) => ({ foodId, meal, servingLabel: s.last.servingLabel, multiplier: s.last.multiplier, grams: s.last.grams }));
}

export function frequentFoods(entries, { sinceDay = '', meal = null } = {}) {
  const c = new Map();
  for (const e of entries) {
    if (e.day < sinceDay || (meal && e.meal !== meal)) continue;
    c.set(e.foodId, (c.get(e.foodId) || 0) + 1);
  }
  return [...c].map(([foodId, count]) => ({ foodId, count })).sort((a, b) => b.count - a.count);
}

// One Touch 推荐：高频的（食物 + 份量 + 餐次）组合
export function oneTouchSuggestions(entries, existing, { sinceDay = '', minCount = 3, max = 4 } = {}) {
  const key = (x) => `${x.foodId}|${x.servingLabel}|${x.multiplier}|${x.meal}`;
  const have = new Set(existing.map(key));
  const c = new Map();
  for (const e of entries) {
    if (e.day < sinceDay) continue;
    const k = key(e);
    if (have.has(k)) continue;
    const s = c.get(k) || { foodId: e.foodId, servingLabel: e.servingLabel, multiplier: e.multiplier, meal: e.meal, count: 0 };
    s.count++; c.set(k, s);
  }
  return [...c.values()].filter((s) => s.count >= minCount).sort((a, b) => b.count - a.count).slice(0, max);
}

// ---------- 建议引擎（§8）----------
const SRC_DIET = '《中国居民膳食指南（2022）》';
const SRC_LIPID = '《中国血脂管理指南（2023 年）》';
const SRC_AHA = '2018 AHA/ACC Guideline on the Management of Blood Cholesterol';

export function swapFor(food, foods, categories) {
  const id = food.swap === undefined ? categories.get(food.category)?.swap : food.swap;
  const s = id && id !== food.id ? foods.get(id) : null;
  return s && gradeOf(s.nutritionPer100g) === 'A' ? s : null;
}

// ctx: { spend, mode, weekly, isOutlier, recentKeys:Set, foods:Map, categories:Map, boosters:[{foodId, servingLabel}] }
// 返回 { key, priority, text, why:{ records, calc, source } }；离群日或无记录返回 null
export function advise(ctx) {
  const { spend, mode, weekly = [], isOutlier, recentKeys = new Set(), foods, categories, boosters = [] } = ctx;
  if (isOutlier || !spend.items.length) return null;
  const budget = satBudget(mode);
  const rec = (i) => ({ name: i.food.name, meal: MEAL_LABEL[i.entry.meal], serving: servingText(i.entry), sat: fmtSat(i.n.sat) });
  const out = [];

  // P0 反式脂肪
  const seen = new Set();
  for (const i of spend.items.filter((x) => x.food.nutritionPer100g.transFatG > 0).sort((a, b) => b.n.trans - a.n.trans)) {
    if (seen.has(i.food.id)) continue;
    seen.add(i.food.id);
    const s = swapFor(i.food, foods, categories);
    out.push({
      key: `P0:${i.food.id}`, priority: 0,
      text: `今天的${i.food.name}含反式脂肪，这类成分对血脂影响最大，${s ? `下次可以换成${s.name}。` : '下次可以换一种不含反式脂肪的做法。'}`,
      why: { records: [rec(i)], calc: `食物库中${i.food.name}的反式脂肪含量大于 0。反式脂肪是零预算项，尽量为 0，上限 ${BUDGET.transMaxG} g。`, source: SRC_DIET },
    });
  }

  // P1 饱和脂肪超出主预算：按预计可省克数排序
  if (spend.total.sat > budget) {
    const all = spend.items.map((i) => {
      const s = swapFor(i.food, foods, categories);
      const saving = s ? i.n.sat - (s.nutritionPer100g.satFatG * i.entry.grams) / 100 : i.n.sat / 2;
      return { i, s, saving };
    }).filter((x) => Math.round(x.saving) >= 1).sort((a, b) => b.saving - a.saving);
    // 可行性：优先动非友好级的食物；全是友好级时才退而求其次
    const notFriendly = all.filter((x) => gradeOf(x.i.food.nutritionPer100g) !== 'A');
    for (const { i, s, saving } of (notFriendly.length ? notFriendly : all).slice(0, 3)) {
      const share = i.n.sat / spend.total.sat;
      out.push({
        key: `P1:${i.food.id}`, priority: 1,
        text: `${i.food.name}约占今天饱和脂肪的${shareWords(share)}（${fmtSat(i.n.sat)}）。${s ? `换成${s.name}` : '份量减半'}，预计可省${fmtSat(saving)}。`,
        why: {
          records: [rec(i)],
          calc: `今天饱和脂肪合计${fmtSat(spend.total.sat)}，超出主预算 ${budget} g。${i.food.name}${fmtSat(i.n.sat)}，占${shareWords(share)}。${s ? `同样份量的${s.name}${fmtSat((s.nutritionPer100g.satFatG * i.entry.grams) / 100)}` : '份量减半后约为原来的一半'}，差值${fmtSat(saving)}。`,
          source: `${SRC_DIET}、${SRC_AHA}`,
        },
      });
    }
  }

  // P2 限额类别本周已达上限
  for (const w of weekly.filter((x) => x.reached)) {
    const cat = categories.get(w.limit.category);
    const s = cat?.swap ? foods.get(cat.swap) : null;
    out.push({
      key: `P2:${w.limit.category}`, priority: 2,
      text: `这周${cat?.name || w.limit.category}已经 ${w.count} 次，${w.over ? '超过上限了' : '到上限了'}。${s ? `接下来几天可以用${s.name}顶上。` : '接下来几天可以先换别的。'}`,
      why: { records: [], calc: `本周（周一至周日）${cat?.name || w.limit.category}记了 ${w.count} 次，上限每周 ${w.limit.maxCount} 次。同一餐同一类别只计 1 次。`, source: '每周次数限额是产品建议值，不是指南原文' },
    });
  }

  // P3 可溶性纤维不足目标的 60%
  if (spend.total.fiber < BUDGET.fiberG * 0.6) {
    for (const b of boosters) {
      const f = foods.get(b.foodId);
      const grams = f?.servings.find((s) => s.label === b.servingLabel)?.grams;
      if (!f || !grams) continue;
      const m = (f.nutritionPer100g.solubleFiberG * grams) / 100;
      out.push({
        key: `P3:${f.id}`, priority: 3,
        text: `今天纤维${fmtFiber(spend.total.fiber)}。明天加一份${f.name}，大约能补 ${Math.max(1, Math.round(m))} g。`,
        why: { records: [], calc: `今天可溶性纤维合计${fmtFiber(spend.total.fiber)}，不足目标 ${BUDGET.fiberG} g 的六成。纤维是独立的储蓄目标，不与饱和脂肪相抵。`, source: SRC_LIPID },
      });
    }
  }

  // P4 膳食胆固醇超出预算
  if (spend.total.chol > BUDGET.cholMg) {
    const top = [...spend.items].sort((a, b) => b.n.chol - a.n.chol)[0];
    const fits = spend.total.chol - top.n.chol / 2 <= BUDGET.cholMg;
    out.push({
      key: `P4:${top.food.id}`, priority: 4,
      text: `今天胆固醇${fmtChol(spend.total.chol)}，主要来自${top.food.name}，${fits ? '明天减半就在预算内。' : '明天这一样减半，会更接近预算。'}`,
      why: { records: [rec(top)], calc: `今天膳食胆固醇合计${fmtChol(spend.total.chol)}，副预算 ${BUDGET.cholMg} mg。${top.food.name}${fmtChol(top.n.chol)}，是最大的一项。`, source: SRC_DIET },
    });
  }

  // 同一条建议 7 天内不重复；命中的规则若会重复，则顺延
  const fresh = out.find((a) => !recentKeys.has(a.key));
  if (fresh) return fresh;
  // 全部命中项都在 7 天内给过：仍给出最高优先级的一条，而不是谎称"都在预算内"
  if (out.length) return out[0];
  return {
    key: 'P5', priority: 5,
    text: '今天各项都在预算内，照这个结构吃就行。',
    why: { records: [], calc: `饱和脂肪${fmtSat(spend.total.sat)}（预算 ${budget} g），胆固醇${fmtChol(spend.total.chol)}（预算 ${BUDGET.cholMg} mg），今天的记录${spend.total.trans > 0 ? '含' : '不含'}反式脂肪。`, source: `${SRC_DIET}、${SRC_LIPID}` },
  };
}

// ---------- 化验区间小结 ----------
export function intervalSummary(entries, foods, limits, outliers, fromDay, toDay) {
  const inRange = entries.filter((e) => e.day >= fromDay && e.day < toDay);
  const totals = totalsByDay(inRange, foods);
  const days = [...totals.keys()].filter((d) => !outliers.has(d));
  if (!days.length) return null;
  const satMean = days.reduce((s, d) => s + totals.get(d).sat, 0) / days.length;
  const fiberDays = days.filter((d) => totals.get(d).fiber >= BUDGET.fiberG).length;
  let weeks = 0, okWeeks = 0;
  for (let ws = weekStart(fromDay); ws < toDay; ws = addDays(ws, 7)) {
    weeks++;
    if (weeklyCounts(inRange, foods, limits, ws).every((w) => !w.over)) okWeeks++;
  }
  return { recordedDays: days.length, satMean, fiberShare: fiberDays / days.length, weeks, okWeeks };
}

// ---------- 导出 ----------
export function toCSV(entries, foods) {
  const q = (s) => `"${String(s ?? '').replace(/"/g, '""')}"`;
  const head = ['日期', '餐次', '食物', '份量', '倍数', '克数', '饱和脂肪(g,估算)', '反式脂肪(g,估算)', '胆固醇(mg,估算)', '可溶性纤维(g,估算)', '录入方式', '示例数据'];
  const rows = [...entries].sort((a, b) => (a.day + a.createdAt).localeCompare(b.day + b.createdAt)).map((e) => {
    const f = foods.get(e.foodId);
    const n = f ? nutritionOf(e, f) : zero();
    return [e.day, MEAL_LABEL[e.meal] || e.meal, f?.name || e.foodId, e.servingLabel, e.multiplier, e.grams,
      n.sat.toFixed(1), n.trans.toFixed(1), Math.round(n.chol), n.fiber.toFixed(1), e.source, e.demo ? '是' : '否'].map(q).join(',');
  });
  return '\ufeff' + [head.map(q).join(','), ...rows].join('\r\n');
}
