import test from 'node:test';
import assert from 'node:assert/strict';
import * as D from '../shared/domain.js';
import { foodMap, CATEGORY_BY_ID, FIBER_BOOSTERS, DEFAULT_LIMITS, FOODS } from '../shared/foods.js';
import { demoDay } from '../shared/demo.js';

const foods = foodMap();
let seq = 0;
const E = (day, meal, foodId, servingLabel, multiplier = 1) => {
  const grams = foods.get(foodId).servings.find((s) => s.label === servingLabel).grams * multiplier;
  return { id: `e${seq++}`, day, meal, foodId, servingLabel, multiplier, grams, source: 'search', createdAt: `${day}T21:00:${String(seq % 60).padStart(2, '0')}+08:00` };
};
const adviseDay = (entries, extra = {}) => D.advise({
  spend: D.dailySpend(entries, foods), mode: 'standard', weekly: [], isOutlier: false,
  foods, categories: CATEGORY_BY_ID, boosters: FIBER_BOOSTERS, ...extra,
});

test('显示精度：取整与口语化', () => {
  assert.equal(D.fmtSat(12.4), '约 12 g');
  assert.equal(D.fmtChol(86), '约 90 mg');
  assert.equal(D.fmtFiber(2.6), '约 3 g');
  assert.equal(D.transLabel(0), '不含反式脂肪');
  assert.equal(D.transLabel(0.2), '含反式脂肪');
  assert.equal(D.roundPct5(0.37), 35);
  assert.equal(D.shareWords(0.52), '一半');
  assert.equal(D.shareWords(0.31), '三成');
  assert.equal(D.shareWords(0.97), '几乎全部');
  assert.equal(D.diffWords(14, 20), '比你平时少三成');
  assert.equal(D.diffWords(20.5, 20), '和你平时差不多');
  assert.equal(D.diffWords(10, 0), null);
});

test('食物分级', () => {
  assert.equal(D.gradeOf({ satFatG: 1.9, transFatG: 0, cholesterolMg: 50 }), 'A');
  assert.equal(D.gradeOf({ satFatG: 2, transFatG: 0, cholesterolMg: 50 }), 'B');
  assert.equal(D.gradeOf({ satFatG: 5, transFatG: 0, cholesterolMg: 0 }), 'C');
  assert.equal(D.gradeOf({ satFatG: 0.5, transFatG: 0.2, cholesterolMg: 0 }), 'C');
  assert.equal(D.gradeOf({ satFatG: 0.5, transFatG: 0, cholesterolMg: 100 }), 'C');
});

test('日期：04:00 前归属前一天；自然周从周一开始', () => {
  assert.equal(D.logicalDay(new Date(2026, 10, 14, 3, 59)), '2026-11-13');
  assert.equal(D.logicalDay(new Date(2026, 10, 14, 4, 0)), '2026-11-14');
  assert.equal(D.weekStart('2026-11-13'), '2026-11-09');
  assert.equal(D.weekStart('2026-11-15'), '2026-11-09');
  assert.equal(D.addDays('2026-03-01', -1), '2026-02-28');
  assert.equal(D.dayLabel('2026-11-03'), '11月3日');
});

test('DailySpend 与 Balance（PRD §5.1 的示意日）', () => {
  const day = '2026-11-13';
  const s = D.dailySpend([E(day, 'breakfast', 'boiled_egg', '个'), E(day, 'breakfast', 'oat_porridge', '中碗'), E(day, 'lunch', 'braised_pork', '中碗'), E(day, 'lunch', 'rice', '中碗')], foods);
  assert.equal(Math.round(s.total.sat), 15);
  assert.equal(D.fmtSat(s.meals.lunch.sat), '约 13 g');
  assert.equal(D.fmtSat(D.balance('standard', s.total.sat)), '约 7 g');
  assert.ok(D.balance('strict', s.total.sat) < 0);
});

test('Baseline：排除离群日，不足 5 天不给相对语言', () => {
  const totals = new Map();
  for (let i = 1; i <= 4; i++) totals.set(D.addDays('2026-11-13', -i), { sat: 20, trans: 0, chol: 0, fiber: 0 });
  assert.equal(D.baseline(totals, new Set(), '2026-11-13'), null);
  totals.set('2026-11-08', { sat: 20, trans: 0, chol: 0, fiber: 0 });
  totals.set('2026-11-07', { sat: 80, trans: 0, chol: 0, fiber: 0 });
  assert.equal(D.baseline(totals, new Set(['2026-11-07']), '2026-11-13').sat, 20);
  assert.equal(D.baseline(totals, new Set(), '2026-11-13').sat, 30);
  totals.set('2026-11-13', { sat: 99, trans: 0, chol: 0, fiber: 0 });
  assert.equal(D.baseline(totals, new Set(['2026-11-07']), '2026-11-13').sat, 20, '当天不计入');
});

test('WeeklyCount：同一餐同一类别计 1 次，跨周不计', () => {
  const entries = [
    E('2026-11-10', 'lunch', 'braised_pork', '中碗'), E('2026-11-10', 'lunch', 'chinese_sausage', '片'),
    E('2026-11-10', 'dinner', 'bacon', '片'), E('2026-11-08', 'lunch', 'braised_pork', '中碗'),
  ];
  const w = D.weeklyCounts(entries, foods, DEFAULT_LIMITS, '2026-11-13');
  const meat = w.find((x) => x.limit.category === 'fatty_processed_meat');
  assert.equal(meat.count, 2);
  assert.equal(meat.reached, true);
  assert.equal(meat.over, false);
  assert.equal(w.find((x) => x.limit.category === 'fried').count, 0);
});

test('SourceRanking 与 HeatLevel', () => {
  const r = D.sourceRanking([E('2026-11-10', 'lunch', 'braised_pork', '中碗'), E('2026-11-10', 'lunch', 'rice', '中碗')], foods);
  assert.equal(r[0].category, 'fatty_processed_meat');
  assert.ok(r[0].share > 0.95);
  const th = D.heatThresholds([1, 2, 3, 4, 5]);
  assert.deepEqual([0, 1, 2, 3, 4, 5, 50].map((v) => D.heatLevel(v, th)), [0, 1, 2, 3, 4, 5, 5]);
  assert.equal(D.heatLevel(3, []), 0);
});

test('重复添加合并份量', () => {
  const a = E('2026-11-13', 'lunch', 'rice', '中碗');
  const m = D.mergeEntry([a], E('2026-11-13', 'lunch', 'rice', '小碗'));
  assert.equal(m.merged, true);
  assert.equal(m.entry.id, a.id);
  assert.equal(m.entry.grams, 250);
  assert.equal(m.entry.multiplier, 1.67);
  assert.equal(D.mergeEntry([a], E('2026-11-13', 'dinner', 'rice', '小碗')).merged, false);
});

test('按习惯预填与 One Touch 推荐', () => {
  const entries = [];
  for (let i = 1; i <= 6; i++) {
    const d = D.addDays('2026-11-13', -i);
    entries.push(E(d, 'breakfast', 'boiled_egg', '个'));
    if (i % 3 === 0) entries.push(E(d, 'breakfast', 'youtiao', '根'));
  }
  const p = D.prefillFor(entries, '2026-11-13', 'breakfast');
  assert.deepEqual(p.map((x) => x.foodId), ['boiled_egg']);
  assert.deepEqual(D.prefillFor(entries, '2026-11-13', 'dinner'), []);
  const s = D.oneTouchSuggestions(entries, []);
  assert.equal(s[0].foodId, 'boiled_egg');
  assert.equal(D.oneTouchSuggestions(entries, [{ foodId: 'boiled_egg', servingLabel: '个', multiplier: 1, meal: 'breakfast' }]).length, 0);
});

test('建议引擎：优先级自上而下', () => {
  const d = '2026-11-13';
  assert.equal(adviseDay([]), null);
  assert.equal(adviseDay([E(d, 'lunch', 'youtiao', '根')], { isOutlier: true }), null);

  const p0 = adviseDay([E(d, 'breakfast', 'youtiao', '根'), E(d, 'lunch', 'braised_pork', '大碗', 2)]);
  assert.equal(p0.key, 'P0:youtiao');
  assert.match(p0.text, /含反式脂肪.*换成馒头/);

  const p1 = adviseDay([E(d, 'lunch', 'braised_pork', '大碗', 1.5), E(d, 'dinner', 'rice', '中碗')]);
  assert.equal(p1.key, 'P1:braised_pork');
  assert.match(p1.text, /红烧肉约占今天饱和脂肪的几乎全部（约 28 g）。换成清蒸鱼，预计可省约 26 g。/);

  const weekly = [{ limit: { category: 'offal', maxCount: 1 }, count: 1, reached: true, over: false }];
  const fiberOk = [E(d, 'breakfast', 'oats', '一份', 4)];
  assert.equal(adviseDay(fiberOk, { weekly }).key, 'P2:offal');

  const p3 = adviseDay([E(d, 'lunch', 'rice', '中碗')]);
  assert.equal(p3.key, 'P3:oat_porridge');

  const p4 = adviseDay([...fiberOk, E(d, 'breakfast', 'boiled_egg', '个', 2)]);
  assert.equal(p4.key, 'P4:boiled_egg');
  assert.match(p4.text, /今天胆固醇约 370 mg，主要来自水煮蛋，明天减半就在预算内。/);

  assert.equal(adviseDay(fiberOk).key, 'P5');
});

test('建议引擎：7 天内不重复，顺延；全部重复时不谎报', () => {
  const d = '2026-11-13';
  const lowFiber = [E(d, 'lunch', 'rice', '中碗')];
  assert.equal(adviseDay(lowFiber, { recentKeys: new Set(['P3:oat_porridge']) }).key, 'P3:red_beans');
  const all = new Set(['P3:oat_porridge', 'P3:red_beans', 'P3:apple']);
  assert.equal(adviseDay(lowFiber, { recentKeys: all }).key, 'P3:oat_porridge');
  const over = [E(d, 'lunch', 'braised_pork', '大碗', 1.5), E(d, 'breakfast', 'oats', '一份', 4)];
  assert.equal(adviseDay(over, { recentKeys: new Set(['P1:braised_pork']) }).key, 'P1:braised_pork');
});

test('建议措辞不含命令或指责', () => {
  const d = '2026-11-13';
  for (const f of FOODS) {
    const a = adviseDay([E(d, 'lunch', f.id, f.servings[0].label, 3)]);
    assert.doesNotMatch(a.text, /你应该|你违反|必须|不许/);
  }
});

test('化验区间小结', () => {
  const entries = [E('2026-11-02', 'lunch', 'braised_pork', '中碗'), E('2026-11-03', 'lunch', 'rice', '中碗'), E('2026-11-03', 'dinner', 'oats', '一份', 7)];
  const s = D.intervalSummary(entries, foods, DEFAULT_LIMITS, new Set(), '2026-11-02', '2026-11-09');
  assert.equal(s.recordedDays, 2);
  assert.equal(s.fiberShare, 0.5);
  assert.equal(s.weeks, 1);
  assert.equal(s.okWeeks, 1);
  assert.equal(D.intervalSummary([], foods, DEFAULT_LIMITS, new Set(), '2026-11-02', '2026-11-09'), null);
});

test('CSV 导出', () => {
  const csv = D.toCSV([E('2026-11-13', 'lunch', 'braised_pork', '中碗')], foods);
  const lines = csv.replace('\ufeff', '').split('\r\n');
  assert.equal(lines.length, 2);
  assert.match(lines[1], /^"2026-11-13","午餐","红烧肉","中碗","1","100","12.4"/);
});

test('示例数据：确定性、带 demo 标记、当天只有早午餐', () => {
  const a = demoDay('2026-10-01', foods), b = demoDay('2026-10-01', foods);
  assert.deepEqual(a, b);
  assert.ok(a.entries.every((e) => e.demo === true && foods.has(e.foodId)));
  const today = demoDay('2026-11-13', foods, 'partial');
  assert.deepEqual([...new Set(today.entries.map((e) => e.meal))], ['breakfast', 'lunch']);
  assert.equal(today.outlier, false);
  const rest = demoDay('2026-11-13', foods, 'rest');
  assert.ok(rest.entries.every((e) => e.meal === 'dinner' || e.meal === 'snack'));
});
