// 分析：热力图、趋势、支出来源、限额执行（PRD §5.3）
import { h, s, group, row, segmented, toggle, tag } from './ui.js';
import { S, refresh, setPrefs, foods, outliers } from './store.js';
import * as D from '../shared/domain.js';
import { CATEGORY_BY_ID } from '../shared/foods.js';
import { demoBanner, pageTitle } from './common.js';

let picked = null;

function heatmap(days, totals, out, thresholds) {
  const cell = (d) => {
    const v = totals.get(d)?.sat;
    const isOut = out.has(d);
    const level = v == null ? 0 : Math.max(1, D.heatLevel(v, thresholds));
    const text = `${D.dayLabel(d)}，${v == null ? '没有记录' : `饱和脂肪${D.fmtSat(v)}`}${isOut ? '，离群日' : ''}`;
    return h('button', { type: 'button', class: `heat l${level} ${isOut ? 'outlier' : ''} ${picked === d ? 'picked' : ''}`, 'aria-label': text, title: text, onClick: () => { picked = d; refresh(); } });
  };
  let grid;
  if (days.length <= 7) grid = h('div', { class: 'heat-row' }, days.map(cell));
  else {
    const cells = [];
    for (let d = D.weekStart(days[0]); d <= D.addDays(D.weekStart(days[days.length - 1]), 6); d = D.addDays(d, 1)) {
      cells.push(d < days[0] || d > days[days.length - 1] ? h('span', { class: 'heat blank' }) : cell(d));
    }
    grid = h('div', { class: 'heat-wrap' },
      h('div', { class: 'heat-days', 'aria-hidden': 'true' }, ['一', '', '三', '', '五', '', '日'].map((t) => h('span', null, t))),
      h('div', { class: 'heat-grid', style: { gridTemplateColumns: `repeat(${cells.length / 7}, minmax(0, 1fr))`, maxWidth: `${(cells.length / 7) * (cells.length / 7 <= 6 ? 38 : 26)}px` } }, cells));
  }
  const pv = picked && totals.get(picked);
  return [
    grid,
    h('div', { class: 'heat-legend' }, h('span', null, '少'), [1, 2, 3, 4, 5].map((l) => h('span', { class: `heat l${l}` })), h('span', null, '多'),
      h('span', { class: 'heat l2 outlier' }), h('span', null, '离群日')),
    h('p', { class: 'chart-cap' }, picked && days.includes(picked)
      ? [`${D.dayLabel(picked)}：${pv ? `饱和脂肪${D.fmtSat(pv.sat)}` : '没有记录'}${out.has(picked) ? ' · 离群日' : ''} `,
        h('button', { class: 'btn plain small', type: 'button', onClick: () => { S.day = picked; S.tab = 'today'; refresh(); window.scrollTo(0, 0); } }, '查看这天')]
      : '颜色深浅按你自己的分布分成五档，不用固定阈值。点一格查看当天。'),
  ];
}

function trend(days, totals, out, excl, budget) {
  const W = 340, H = 150, L = 6, R = 6, T = 14, B = 20;
  const pts = days.map((d, i) => ({ d, i, v: totals.get(d)?.sat })).filter((p) => p.v != null && !(excl && out.has(p.d)));
  if (pts.length < 2) return h('p', { class: 'chart-cap' }, '记录满两天后，这里会画出日支出折线。');
  const baseAll = D.totalsByDay(S.data.entries, foods());
  const base = days.map((d, i) => ({ i, v: D.baseline(baseAll, out, D.addDays(d, 1))?.sat })).filter((p) => p.v != null);
  const max = Math.max(budget, ...pts.map((p) => p.v), ...base.map((p) => p.v)) * 1.08;
  const x = (i) => L + (i / Math.max(1, days.length - 1)) * (W - L - R);
  const y = (v) => T + (1 - v / max) * (H - T - B);
  const line = (arr) => arr.map((p) => `${x(p.i).toFixed(1)},${y(p.v).toFixed(1)}`).join(' ');
  const mean = pts.reduce((a, p) => a + p.v, 0) / pts.length;
  return [
    s('svg', { class: 'chart', viewBox: `0 0 ${W} ${H}`, role: 'img', 'aria-label': `饱和脂肪日支出折线。${pts.length} 个记录日，日均${D.fmtSat(mean)}，预算 ${budget} g。` },
      s('line', { class: 'ref', x1: L, x2: W - R, y1: y(budget), y2: y(budget) }),
      
      base.length > 1 && s('polyline', { class: 'base', points: line(base) }),
      s('polyline', { class: 'spend', points: line(pts) }),
      days.length <= 31 && pts.map((p) => s('circle', { class: 'dot', cx: x(p.i), cy: y(p.v), r: 2.2 })),
      s('text', { class: 'ref-label', x: L, y: y(budget) - 4 }, `预算 ${budget} g`),
      s('text', { class: 'axis', x: L, y: H - 4 }, D.dayLabel(days[0])),
      s('text', { class: 'axis', x: W - R, y: H - 4, 'text-anchor': 'end' }, D.dayLabel(days[days.length - 1]))),
    h('div', { class: 'legend' },
      h('span', null, s('svg', { width: 22, height: 8, 'aria-hidden': 'true' }, s('line', { class: 'spend', x1: 0, x2: 22, y1: 4, y2: 4 })), '日支出'),
      h('span', null, s('svg', { width: 22, height: 8, 'aria-hidden': 'true' }, s('line', { class: 'base', x1: 0, x2: 22, y1: 4, y2: 4 })), '14 天水位'),
      h('span', null, s('svg', { width: 22, height: 8, 'aria-hidden': 'true' }, s('line', { class: 'ref', x1: 0, x2: 22, y1: 4, y2: 4 })), '预算')),
  ];
}

export function renderAnalysis() {
  const F = foods(), out = outliers(), range = S.prefs.range, excl = S.prefs.excludeOutliers;
  const budget = D.satBudget(S.data.settings.budgetMode);
  const days = D.dayRange(S.today, range);
  const allTotals = D.totalsByDay(S.data.entries, F);
  const inRange = S.data.entries.filter((e) => e.day >= days[0] && e.day <= S.today);
  const counted = inRange.filter((e) => !(excl && out.has(e.day)));
  const totals = D.totalsByDay(inRange, F);
  const thresholds = D.heatThresholds([...allTotals].filter(([d]) => !(excl && out.has(d))).map(([, t]) => t.sat));
  const label = range === 7 ? '过去 7 天' : range === 30 ? '过去 30 天' : '过去 90 天';

  const head = [
    pageTitle('分析'),
    demoBanner(),
    h('div', { class: 'pad' }, segmented([[7, '周'], [30, '月'], [90, '90 天']], range, (v) => { picked = null; setPrefs({ range: v }); }, '时间范围')),
    group({}, row({ title: '排除离群日', sub: '离群日仍显示在热力图上，但不计入趋势、来源和小结', trailing: toggle(excl, (v) => setPrefs({ excludeOutliers: v }), '排除离群日') })),
  ];
  if (!inRange.length) return [head, h('p', { class: 'sheet-note' }, `${label}没有记录。记几天后，这里会出现你的热力图和趋势。`)];

  const ranking = D.sourceRanking(counted, F);
  const recDays = [...D.totalsByDay(counted, F)];
  const mean = recDays.reduce((a, [, t]) => a + t.sat, 0) / (recDays.length || 1);
  const overDays = recDays.filter(([, t]) => t.sat > budget).length;
  const names = ranking.slice(0, 2).map((r) => CATEGORY_BY_ID.get(r.category)?.name);
  const share2 = ranking.slice(0, 2).reduce((a, r) => a + r.share, 0);

  const weeks = [];
  for (let w = D.weekStart(days[0]); w <= S.today; w = D.addDays(w, 7)) weeks.push(w);
  const limitRows = S.data.limits.map((limit) => {
    const cat = CATEGORY_BY_ID.get(limit.category);
    const counts = weeks.map((w) => D.weeklyCounts(S.data.entries, F, [limit], w)[0].count);
    const ok = counts.filter((c) => c <= limit.maxCount).length;
    return row({
      emoji: cat?.emoji, title: cat?.name,
      sub: range === 7 ? `上限每周 ${limit.maxCount} 次` : h('span', { class: 'weeks', 'aria-label': `各周次数：${counts.join('、')}` }, counts.map((c) => h('span', { class: `wk num ${c > limit.maxCount ? 'over' : ''}` }, c > limit.maxCount ? `${c}!` : c))),
      value: range === 7 ? `本周 ${counts[counts.length - 1]} / ${limit.maxCount} 次` : `${ok} / ${weeks.length} 周在限额内`,
    });
  });

  return [
    head,
    group({ title: '小结', headline: true },
      h('p', { class: 'cell-text' }, ranking.length && ranking[0].sat > 0
        ? `${label}，你的饱和脂肪约${D.shareWords(share2)}来自${names.filter(Boolean).join('与')}。有记录的 ${recDays.length} 天里，日均${D.fmtSat(mean)}，${overDays} 天超出预算。`
        : `${label}的记录里几乎没有饱和脂肪。`)),
    h('section', { class: 'group' }, h('div', { class: 'group-head headline' }, h('h2', null, '热力图'), S.data.settings.demo && tag('示例')),
      h('div', { class: 'card' }, heatmap(days, totals, out, thresholds))),
    h('section', { class: 'group' }, h('div', { class: 'group-head headline' }, h('h2', null, '趋势')),
      h('div', { class: 'card' }, trend(days, totals, out, excl, budget))),
    group({ title: '支出来源', headline: true, footer: '按食物类别累计饱和脂肪，显示前 5 项。占比取整到 5%。' },
      ranking.slice(0, 5).filter((r) => r.sat > 0).map((r) => {
        const cat = CATEGORY_BY_ID.get(r.category);
        return row({ emoji: cat?.emoji, title: cat?.name, sub: h('span', { class: 'bar', 'aria-hidden': 'true' }, h('span', { style: { width: `${Math.max(2, r.share * 100)}%` } })), value: `约 ${D.roundPct5(r.share)}%` });
      })),
    group({ title: '限额执行', headline: true, footer: range === 7 ? '限额按自然周计数，不受“排除离群日”影响。' : '每个数字是一个自然周的次数，带 ! 的是超出上限的周。限额不受“排除离群日”影响。' },
      limitRows.length ? limitRows : row({ cls: 'guide', title: '还没有设置限额' })),
  ];
}
