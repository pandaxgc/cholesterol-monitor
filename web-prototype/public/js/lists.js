// 清单：智能列表、我的常吃、食物库（PRD §5.2）
import { h, icon, group, row, gradeBadge, emoji, openSheet, toast } from './ui.js';
import { S, refresh, foods, addOneTouch, setServingOverride } from './store.js';
import * as D from '../shared/domain.js';
import { CATEGORIES, CATEGORY_BY_ID, FOODS } from '../shared/foods.js';
import { openKeypad, foodRow, matchFoods, oneTouchResultText } from './add.js';
import { demoBanner, pageTitle } from './common.js';

let query = '';
const relDay = (n) => (n === 0 ? '今天' : n === 1 ? '昨天' : n <= 7 ? `${n} 天前` : null);

function entryList(title, entries, emptyText) {
  const F = foods();
  openSheet({
    title, tall: true,
    build: () => (entries.length ? group({}, [...entries].sort((a, b) => b.day.localeCompare(a.day)).map((e) => {
      const food = F.get(e.foodId);
      return row({ emoji: food.emoji, title: food.name, badge: gradeBadge(D.gradeOf(food.nutritionPer100g)), sub: `${D.dayLabel(e.day)} · ${D.MEAL_LABEL[e.meal]} · ${D.servingText(e)}`, value: D.fmtSat(D.nutritionOf(e, food).sat), onClick: () => openFoodDetail(food) });
    })) : h('p', { class: 'sheet-note' }, emptyText)),
  });
}

export function openFoodDetail(food0) {
  openSheet({
    title: food0.name, tall: true,
    build: () => {
      const food = foods().get(food0.id);
      const n = food.nutritionPer100g, grade = D.gradeOf(n);
      const base = FOODS.find((f) => f.id === food.id);
      const recent = [...new Set(S.data.entries.filter((e) => e.foodId === food.id).map((e) => e.day))].sort().reverse().slice(0, 5);
      return [
        h('div', { class: 'food-hero' }, h('span', { class: 'hero-emoji', 'aria-hidden': 'true' }, food.emoji), h('div', null, h('div', { class: 'hero-name' }, food.name), gradeBadge(grade),
          food.aliases.length ? h('div', { class: 'muted small' }, `也叫：${food.aliases.join('、')}`) : null)),
        h('div', { class: 'btn-row' }, h('button', { class: 'btn', type: 'button', onClick: () => openKeypad({ food, meal: 'snack' }) }, `记一笔到 ${D.dayLabel(S.day)}`)),
        group({ title: '每 100 g 可食部', footer: `类别：${CATEGORY_BY_ID.get(food.category)?.name}。显示值已按规则取整。` },
          row({ title: '饱和脂肪', value: D.fmtSat(n.satFatG) }),
          row({ title: '反式脂肪', value: n.transFatG > 0 ? '含' : '不含' }),
          row({ title: '膳食胆固醇', value: D.fmtChol(n.cholesterolMg) }),
          row({ title: '可溶性纤维', value: D.fmtFiber(n.solubleFiberG) })),
        group({ title: '份量校准', footer: '每个量具绑定一个默认克数。你家的碗大一些或小一些，可以在这里改；留空恢复默认。' },
          food.servings.map((sv, i) => row({
            title: sv.label, sub: `默认 ${base.servings[i].grams} g`,
            trailing: h('label', { class: 'grams' }, h('input', {
              type: 'number', inputmode: 'numeric', min: 1, max: 2000, value: sv.grams, 'aria-label': `${sv.label}的克数`,
              onChange: (e) => { const v = Math.round(Number(e.target.value)); setServingOverride(food.id, sv.label, v > 0 && v <= 2000 && v !== base.servings[i].grams ? v : 0); refresh(); },
            }), 'g'),
          }))),
        group({ title: '数据来源' }, row({ title: food.source, sub: `数据版本 ${food.dataVersion}` })),
        group({ title: '最近吃过' }, recent.length ? recent.map((d) => row({ title: D.dayLabel(d), value: relDay(D.diffDays(S.today, d)) })) : row({ cls: 'guide', title: '还没有记录' })),
      ];
    },
  });
}

function categorySheet(cat) {
  openSheet({ title: cat.name, tall: true, build: () => group({}, [...foods().values()].filter((f) => f.category === cat.id).map((f) => foodRow(f, () => openFoodDetail(f), { chevron: true }))) });
}

function library(host) {
  const F = foods();
  if (query.trim()) {
    const hits = matchFoods(query);
    host.replaceChildren(hits.length ? group({}, hits.map((f) => foodRow(f, () => openFoodDetail(f), { chevron: true }))) : h('p', { class: 'sheet-note' }, `没有找到“${query.trim()}”。`));
    return;
  }
  const use = new Map();
  for (const e of S.data.entries) { const c = F.get(e.foodId)?.category; if (c) use.set(c, (use.get(c) || 0) + 1); }
  const cats = [...CATEGORIES].sort((a, b) => (use.get(b.id) || 0) - (use.get(a.id) || 0));
  host.replaceChildren(group({ footer: `共 ${F.size} 种食物，类别按你的使用量排序。营养数值为估算值，尚未对照《中国食物成分表》核实。` },
    cats.map((c) => row({ emoji: c.emoji, title: c.name, value: `${[...F.values()].filter((f) => f.category === c.id).length} 种`, chevron: true, onClick: () => categorySheet(c) }))));
}

export function renderLists() {
  const F = foods(), entries = S.data.entries.filter((e) => F.has(e.foodId));
  const ws = D.weekStart(S.today), d7 = D.addDays(S.today, -6), d30 = D.addDays(S.today, -29);
  const week = entries.filter((e) => e.day >= ws && e.day <= S.today);
  const watch = week.filter((e) => D.gradeOf(F.get(e.foodId).nutritionPer100g) === 'C');
  const limitCats = new Set(S.data.limits.map((l) => l.category));
  const limited = week.filter((e) => limitCats.has(F.get(e.foodId).category));
  const out = entries.filter((e) => e.day >= d7 && F.get(e.foodId).category === 'dining_out');
  const trans = entries.filter((e) => e.day >= d30 && F.get(e.foodId).nutritionPer100g.transFatG > 0);
  const smart = [
    ['eye', '本周留意级食物', watch, '这周还没有留意级的食物。'],
    ['gauge', '本周限额类别', limited, '这周还没有限额类别的记录。'],
    ['fork', '最近 7 天外食', out, '最近 7 天没有外食记录。'],
    ['alert', '含反式脂肪的记录', trans, '最近 30 天没有含反式脂肪的记录。'],
  ];
  const usual = D.frequentFoods(entries, { sinceDay: d30 }).slice(0, 8);
  const libHost = h('div');
  library(libHost);
  return [
    pageTitle('清单'),
    demoBanner(),
    group({ title: '智能列表', headline: true }, smart.map(([e, title, list, empty]) => row({ lead: h('span', { class: 'row-icon' }, icon(e, 24)), title, value: `${list.length}`, chevron: true, onClick: () => entryList(title, list, empty) }))),
    group({ title: '我的常吃', headline: true, footer: usual.length ? '按最近 30 天的使用频率排序。点 ⚡ 转为 One Touch。' : null },
      usual.length ? usual.map(({ foodId, count }) => {
        const food = F.get(foodId);
        const last = [...entries].filter((e) => e.foodId === foodId).sort((a, b) => b.createdAt.localeCompare(a.createdAt))[0];
        return row({
          emoji: food.emoji, title: food.name, sub: `${count} 次 · 常用 ${D.servingText(last)}`, onClick: () => openFoodDetail(food),
          trailing: h('button', { class: 'row-act', type: 'button', 'aria-label': `把${food.name}存为 One Touch`, onClick: () => { toast(oneTouchResultText(addOneTouch(last))); refresh(); } }, icon('bolt', 18)),
        });
      }) : row({ cls: 'guide', title: '记录几天后，这里会列出你最常吃的食物' })),
    h('section', { class: 'group' }, h('div', { class: 'group-head headline' }, h('h2', null, '食物库')),
      h('input', { type: 'search', class: 'search', placeholder: '搜索食物库', 'aria-label': '搜索食物库', value: query, autocomplete: 'off', onInput: (e) => { query = e.target.value; library(libHost); } })),
    libHost,
  ];
}
