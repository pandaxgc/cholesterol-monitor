// 今日：预算余额 + 今日流水（PRD §5.1）
import { h, icon, group, row, gradeBadge, tag, amount, tile, navBar, glassBtn, statGrid, openSheet, actionSheet, toast, haptic } from './ui.js';
import { S, refresh, foods, dayContext, addEntry, deleteEntry, toggleOutlier, saveAdvice, addOneTouch } from './store.js';
import * as D from '../shared/domain.js';
import { CATEGORY_BY_ID } from '../shared/foods.js';
import { openAddPanel, openKeypad, oneTouchResultText } from './add.js';
import { openSettings } from './settings.js';
import { demoBanner } from './common.js';

const WEEKDAYS = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
const reducedMotion = () => window.matchMedia('(prefers-reduced-motion: reduce)').matches;
let shown = null; // 上一次显示的余额，用于数字滚动

function animateNumber(el, from, to, fmt) {
  if (from == null || from === to || reducedMotion()) { el.textContent = fmt(to); return; }
  const t0 = performance.now(), dur = 450;
  const step = (t) => {
    const k = Math.min(1, (t - t0) / dur), e = 1 - (1 - k) ** 3;
    el.textContent = fmt(Math.round(from + (to - from) * e));
    if (k < 1 && el.isConnected) requestAnimationFrame(step);
  };
  requestAnimationFrame(step);
}

export function entryLabel(food, entry, n) {
  return `${food.name}，${D.servingText(entry)}，饱和脂肪约 ${Math.round(n.sat)} 克，${D.GRADE_LABEL[D.gradeOf(food.nutritionPer100g)]}。`;
}

export function entryRow({ entry, food, n }, onClick) {
  const grade = D.gradeOf(food.nutritionPer100g);
  return row({
    emoji: food.emoji, title: food.name, detail: D.servingText(entry), badge: grade !== 'A' && gradeBadge(grade),
    value: D.fmtSat(n.sat), onClick, label: entryLabel(food, entry, n),
  });
}

function setDay(day) { S.day = day > S.today ? S.today : day; shown = null; refresh(); }

function header(c) {
  const isToday = S.day === S.today;
  const picker = h('input', { type: 'date', class: 'visually-hidden', max: S.today, value: S.day, tabindex: '-1', 'aria-hidden': 'true', onChange: (e) => e.target.value && setDay(e.target.value) });
  const label = `${D.dayLabel(S.day)} ${WEEKDAYS[D.weekday(S.day)]}`;
  return [
    navBar({
      left: glassBtn('person', '设置', () => openSettings()),
      title: [h('button', { class: 'title-chip', type: 'button', 'aria-label': `${isToday ? '今日，' : ''}${label}。日期与离群日`, onClick: () => dayMenu(c, picker) },
        h('h1', { class: 'num' }, isToday ? '今日' : label), c.isOutlier && tag('离群日'), h('span', { class: 'chip-chev' }, icon('chevronDown', 12))), picker],
      right: h('div', { class: 'glass-cap' },
        h('button', { type: 'button', 'aria-label': '前一天', onClick: () => setDay(D.addDays(S.day, -1)) }, icon('chevronLeft', 20)),
        h('button', { type: 'button', 'aria-label': '后一天', disabled: isToday, onClick: () => setDay(D.addDays(S.day, 1)) }, icon('chevronRight', 20))),
    }),
    isToday && new Date().getHours() < 4 && h('p', { class: 'title-note' }, `现在是凌晨，记在 ${D.dayLabel(S.day)}`),
  ];
}

function dayMenu(c, picker) {
  const isToday = S.day === S.today;
  actionSheet({
    title: `${D.dayLabel(S.day)} ${WEEKDAYS[D.weekday(S.day)]}`,
    note: '离群日照常记录和显示，但不计入日常水位，也不触发当日建议。适合聚餐、节日这样的日子。',
    actions: [
      { label: '选择日期', icon: 'calendar', onClick: () => { try { picker.showPicker(); } catch { picker.focus(); } } },
      !isToday && { label: '回到今天', icon: 'today', onClick: () => setDay(S.today) },
      {
        label: c.isOutlier ? '取消离群日标记' : '标记为离群日', icon: c.isOutlier ? 'close' : 'check',
        onClick: () => { const on = toggleOutlier(S.day); refresh(); toast(on ? '已标记为离群日' : '已取消离群日标记'); },
      },
    ],
  });
}

function balanceBlock(c) {
  const used = Math.round(c.spend.total.sat);
  const bal = c.budget - used;
  const over = bal < 0;
  const num = h('span', { class: 'n' });
  animateNumber(num, shown, bal, (v) => String(Math.abs(v)));
  shown = bal;
  let rel;
  if (c.isOutlier) rel = '今天是离群日，不计入日常水位';
  else if (!c.base) rel = '记满 5 个非离群日后，会和你的日常水位比较';
  else if (c.complete) rel = `今天的饱和脂肪${D.diffWords(c.spend.total.sat, c.base.sat)}`;
  else rel = '三餐记完后，会和你的日常水位比较';
  return h('button', {
    class: 'balance', type: 'button', onClick: () => sourcesSheet(c),
    'aria-label': `饱和脂肪余额，${over ? `已超出约 ${-bal} 克` : `约 ${bal} 克`}。已用约 ${used} 克，预算 ${c.budget} 克。点按查看来源明细`,
  },
    h('div', { class: 'balance-cap' }, '饱和脂肪余额', c.mode === 'strict' && ' · 严格模式'),
    h('div', { class: `balance-fig ${over ? 'over' : ''}` }, h('span', { class: 'pre' }, over ? '已超出约' : '约'), num, h('span', { class: 'unit' }, 'g')),
    h('div', { class: 'progress-row' },
      h('div', { class: 'progress', 'aria-hidden': 'true' }, h('div', { class: over ? 'over' : '', style: { transform: `translateX(${Math.min(100, (used / c.budget) * 100) - 100}%)` } })),
      amount(`${used} / ${c.budget} g`)),
    h('div', { class: 'balance-rel' }, rel));
}

function sourcesSheet(c) {
  openSheet({
    title: '今日饱和脂肪来源',
    build: () => {
      const items = [...c.spend.items].sort((a, b) => b.n.sat - a.n.sat);
      if (!items.length) return h('p', { class: 'sheet-note' }, '这一天还没有记录。');
      return [
        group({ footer: '按贡献从高到低排列。数值为估算，已取整。' }, items.map((i) => row({
          emoji: i.food.emoji, title: i.food.name, sub: `${D.MEAL_LABEL[i.entry.meal]} · ${D.servingText(i.entry)}`,
          value: `${D.fmtSat(i.n.sat)} · 约 ${D.roundPct5(c.spend.total.sat ? i.n.sat / c.spend.total.sat : 0)}%`,
        }))),
      ];
    },
  });
}

function summaryGroup(c) {
  const t = c.spend.total;
  const transFoods = [...new Set(c.spend.items.filter((i) => i.food.nutritionPer100g.transFatG > 0).map((i) => i.food.name))];
  const cholOver = t.chol > D.BUDGET.cholMg;
  const overLimits = c.weekly.filter((w) => w.over).length;
  return [
    statGrid([
      { label: '膳食胆固醇', value: `${D.fmtChol(t.chol).replace(' mg', '')} / ${D.BUDGET.cholMg} mg`, cls: cholOver ? 'warn-text' : '', note: cholOver ? '超出' : null },
      { label: '可溶性纤维', value: `${D.fmtFiber(t.fiber).replace(' g', '')} / ${D.BUDGET.fiberG} g` },
      { label: '反式脂肪', value: transFoods.length ? '含' : '不含', cls: transFoods.length ? 'warn-text' : '', note: transFoods.join('、') || null },
      { label: '你的日常水位', value: c.base ? `每天${D.fmtSat(c.base.sat)}` : '—', note: c.base ? null : '记满 5 天后显示' },
    ]),
    group({},
      row({
        lead: tile('gauge'), title: '本周限额', chevron: true, onClick: () => limitsSheet(c),
        value: !c.weekly.length ? '未设置' : overLimits ? `${overLimits} 项超出` : null, valueCls: overLimits ? 'warn-text' : '',
        sub: c.weekly.length ? h('span', { class: 'limit-list' }, c.weekly.map((w) => h('span', { class: w.over ? 'warn-text' : '' }, `${CATEGORY_BY_ID.get(w.limit.category)?.short || w.limit.category} `, h('span', { class: 'num' }, `${w.count}/${w.limit.maxCount}`)))) : null,
      })),
  ];
}

function limitsSheet(c) {
  openSheet({
    title: '本周限额',
    build: (sheet) => [
      group({ footer: '自然周（周一至周日）内计数；一餐内同一类别无论几样食物，只计 1 次。默认限额为产品建议值，不是指南原文。' },
        c.weekly.map((w) => {
          const cat = CATEGORY_BY_ID.get(w.limit.category);
          const left = w.limit.maxCount - w.count;
          return row({ emoji: cat?.emoji, title: cat?.name, sub: left > 0 ? `还可 ${left} 次` : left === 0 ? '已到上限' : `超出 ${-left} 次`, value: `${w.count} / ${w.limit.maxCount} 次`, valueCls: left < 0 ? 'warn-text' : '' });
        })),
      h('div', { class: 'btn-row' }, h('button', { class: 'btn secondary', type: 'button', onClick: () => { sheet.close(); openSettings(); } }, '在设置中修改限额')),
    ],
  });
}

function entryMenu(item) {
  const { entry, food } = item;
  const others = D.MEALS.filter((m) => m !== entry.meal);
  actionSheet({
    title: `${food.name} · ${D.servingText(entry)}`,
    actions: (sheet) => [
      { label: '编辑份量', icon: 'pencil', onClick: () => openKeypad({ food, meal: entry.meal, entry }) },
      {
        node: row({
          lead: h('span', { class: 'row-icon' }, icon('copy', 20)), title: '复制到',
          trailing: h('div', { class: 'inline-chips' }, others.map((m) => h('button', {
            class: 'chip', type: 'button', onClick: () => {
              const r = addEntry({ day: entry.day, meal: m, food, servingLabel: entry.servingLabel, multiplier: entry.multiplier, source: 'search' });
              sheet.close(); refresh(); toast(`已复制到${D.MEAL_LABEL[m]}`, { undo: r.undo });
            },
          }, D.MEAL_LABEL[m]))),
        }),
      },
      { label: '存为 One Touch', icon: 'bolt', onClick: () => { toast(oneTouchResultText(addOneTouch(entry))); refresh(); } },
      { label: '删除', icon: 'trash', danger: true, onClick: () => { const undo = deleteEntry(entry); refresh(); toast(`已删除${food.name}`, { undo }); } },
    ],
  });
}

function mealGroup(c, meal) {
  const items = c.spend.items.filter((i) => i.entry.meal === meal);
  const F = foods();
  const rows = items.map((i) => entryRow(i, () => entryMenu(i)));
  // 预填条目在该餐只有预填确认的记录时继续显示，方便逐条确认
  const canPrefill = S.day === S.today && !c.isOutlier && items.every((i) => i.entry.source === 'prefill');
  const have = new Set(items.map((i) => i.food.id));
  const pre = canPrefill ? D.prefillFor(S.data.entries, S.day, meal).filter((p) => !have.has(p.foodId) && F.has(p.foodId)) : [];
  for (const p of pre) {
    const food = F.get(p.foodId);
    const n = D.nutritionOf(p, food);
    rows.push(row({
      cls: 'prefill', emoji: food.emoji, title: food.name, detail: D.servingText(p), sub: '按习惯预填 · 点一下确认', value: D.fmtSat(n.sat),
      label: `按习惯预填：${food.name}，${D.servingText(p)}。点按确认入账`,
      onClick: () => {
        const r = addEntry({ day: S.day, meal, food, servingLabel: p.servingLabel, multiplier: p.multiplier, source: 'prefill' });
        haptic(); refresh(); toast(`已记入${D.MEAL_LABEL[meal]}：${food.name}`, { undo: r.undo });
      },
    }));
  }
  if (!items.length) rows.push(row({ cls: 'guide', title: pre.length ? '记别的' : '还没记，点这里补上', chevron: true, onClick: () => openAddPanel({ meal }) }));
  return group({ title: D.MEAL_LABEL[meal], headline: true, right: items.length ? D.fmtSat(c.spend.meals[meal].sat) : null }, rows);
}

function adviceGroup(c) {
  if (c.isOutlier) return group({ title: '今日建议', headline: true }, row({ title: '今天不计入日常水位', sub: '离群日不生成建议。' }));
  if (!c.advice) return group({ title: '今日建议', headline: true }, row({ cls: 'guide', title: '记下第一笔后，这里会给出一条建议' }));
  const a = c.advice;
  return group({ title: '今日建议', headline: true, footer: c.complete ? null : '三餐还没记完，建议会随记录更新。' },
    row({ cls: 'advice', title: a.text, chevron: true, label: `${a.text} 点按查看为什么`, onClick: () => whySheet(a) }));
}

function whySheet(a) {
  openSheet({
    title: '为什么',
    build: () => [
      h('p', { class: 'sheet-note strong' }, a.text),
      a.why.records.length ? group({ title: '涉及的记录' }, a.why.records.map((r) => row({ title: r.name, sub: `${r.meal} · ${r.serving}`, value: r.sat }))) : null,
      group({ title: '计算过程' }, h('p', { class: 'cell-text' }, a.why.calc)),
      group({ title: '依据', footer: '建议由固定规则生成，不使用生成式模型；同样的记录总会得到同样的建议。数值为估算。' }, h('p', { class: 'cell-text' }, a.why.source)),
    ],
  });
}

export function renderToday() {
  const c = dayContext(S.day);
  if (S.day === S.today) saveAdvice(S.day, c.advice?.key || null);
  const meals = [...D.MAIN_MEALS, ...(c.dayEntries.some((e) => e.meal === 'snack') ? ['snack'] : [])];
  let done = null;
  if (c.complete) {
    const key = `done:${S.day}`;
    const first = S.day === S.today && !sessionStorage.getItem(key);
    if (first) { sessionStorage.setItem(key, '1'); haptic('success'); }
    done = h('p', { class: `done-line ${first ? 'pulse' : ''}` }, icon('check', 18), S.day === S.today ? '今日已记完' : '这一天三餐都记了');
  }
  return [
    header(c),
    demoBanner(),
    balanceBlock(c),
    summaryGroup(c),
    meals.map((m) => mealGroup(c, m)),
    done,
    adviceGroup(c),
  ];
}
