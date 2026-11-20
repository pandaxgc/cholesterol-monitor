// 晚间批量补记：添加面板、份量键盘、One Touch（PRD §6、§3.6）
import { h, icon, group, row, gradeBadge, emoji, amount, segmented, openSheet, toast, haptic } from './ui.js';
import { S, refresh, foods, addEntry, updateEntry, addOneTouch, sortedOneTouch } from './store.js';
import * as D from '../shared/domain.js';
import { CATEGORIES } from '../shared/foods.js';
import { openSettings } from './settings.js';

const MEAL_OPTIONS = D.MEALS.map((m) => [m, D.MEAL_LABEL[m]]);

export const oneTouchResultText = (r) => (r === 'ok' ? '已存为 One Touch' : r === 'exists' ? '已经有相同的 One Touch' : `One Touch 已满 ${D.MAX_ONE_TOUCH} 个，先在设置里删掉一个`);

function defaultMeal() {
  const have = new Set(S.data.entries.filter((e) => e.day === S.day).map((e) => e.meal));
  return D.MAIN_MEALS.find((m) => !have.has(m)) || 'snack';
}

export function matchFoods(q) {
  const k = q.trim().toLowerCase();
  if (!k) return [];
  return [...foods().values()].filter((f) => f.name.toLowerCase().includes(k) || f.aliases.some((a) => a.toLowerCase().includes(k)));
}

export function foodRow(food, onClick, extra = {}) {
  const sv = food.servings[food.defaultServing];
  const grade = D.gradeOf(food.nutritionPer100g);
  return row({
    emoji: food.emoji, title: food.name, badge: gradeBadge(grade),
    value: `${sv.label} ${D.fmtSat((food.nutritionPer100g.satFatG * sv.grams) / 100)}`, onClick,
    label: `${food.name}，${D.GRADE_LABEL[grade]}，${sv.label}饱和脂肪约 ${Math.round((food.nutritionPer100g.satFatG * sv.grams) / 100)} 克`, ...extra,
  });
}

// ---------- 添加面板：提交一条后不关闭，停在当前餐次继续添加 ----------
const A = { meal: 'breakfast', q: '', cat: null };

export function openAddPanel({ meal, focusSearch = false } = {}) {
  A.meal = meal || defaultMeal(); A.q = ''; A.cat = null;
  const results = h('div');
  const mealHost = h('div', { class: 'pad' });
  const input = h('input', { type: 'search', class: 'search', placeholder: '搜索食物，例如 红烧肉', 'aria-label': '搜索食物', autocomplete: 'off', enterkeyhint: 'search', onInput: (e) => { A.q = e.target.value; fill(); } });

  function fill() {
    mealHost.replaceChildren(segmented(MEAL_OPTIONS, A.meal, (m) => { A.meal = m; fill(); }, '餐次'));
    const F = foods();
    const pick = (food) => openKeypad({ food, meal: A.meal, onLogged: (m) => { A.meal = m; fill(); } });
    const logged = S.data.entries.filter((e) => e.day === S.day && e.meal === A.meal).map((e) => F.get(e.foodId)?.name).filter(Boolean);
    const out = [h('p', { class: 'add-status' }, logged.length ? `${D.MEAL_LABEL[A.meal]}已记：${logged.join('、')}` : `${D.MEAL_LABEL[A.meal]}还没有记录`)];
    if (A.q.trim()) {
      const hits = matchFoods(A.q);
      out.push(hits.length ? group({ title: `找到 ${hits.length} 种` }, hits.map((f) => foodRow(f, () => pick(f))))
        : h('p', { class: 'sheet-note' }, `没有找到“${A.q.trim()}”。外食不知道具体食材时，可以先按类型归档，例如“外卖盖饭”“中式宴席”。`));
    } else {
      const since = D.addDays(S.today, -30);
      const usual = D.frequentFoods(S.data.entries, { sinceDay: since, meal: A.meal }).slice(0, 5).map((x) => F.get(x.foodId)).filter(Boolean);
      if (usual.length) out.push(group({ title: `${D.MEAL_LABEL[A.meal]}常吃` }, usual.map((f) => foodRow(f, () => pick(f)))));
      const use = new Map();
      for (const e of S.data.entries) { const c = F.get(e.foodId)?.category; if (c) use.set(c, (use.get(c) || 0) + 1); }
      const cats = [...CATEGORIES].sort((a, b) => (use.get(b.id) || 0) - (use.get(a.id) || 0));
      if (!A.cat) A.cat = cats[0].id;
      out.push(h('div', { class: 'chips', role: 'group', 'aria-label': '食物类别' }, cats.map((c) => h('button', { class: 'chip', type: 'button', 'aria-pressed': String(c.id === A.cat), onClick: () => { A.cat = c.id; fill(); } }, emoji(c.emoji), c.name))));
      out.push(group({}, [...F.values()].filter((f) => f.category === A.cat).map((f) => foodRow(f, () => pick(f)))));
    }
    results.replaceChildren(...out.flat());
  }

  const sheet = openSheet({
    title: `补记 · ${D.dayLabel(S.day)}`, tall: true,
    build: () => [mealHost, h('div', { class: 'pad' }, input), results],
    update: fill,
  });
  fill();
  if (focusSearch) input.focus();
  return sheet;
}

// ---------- 份量键盘 ----------
const MULTS = [0.5, 1, 1.5, 2];
const multLabel = (m) => (m === 0.5 ? '½' : `×${m}`);

export function openKeypad({ food, meal, entry = null, onLogged }) {
  const last = entry || D.lastServing(S.data.entries, food.id);
  const K = {
    meal,
    servingLabel: food.servings.some((x) => x.label === last?.servingLabel) ? last.servingLabel : food.servings[food.defaultServing].label,
    multiplier: last?.multiplier || 1,
  };
  const grade = D.gradeOf(food.nutritionPer100g);
  const grams = () => food.servings.find((x) => x.label === K.servingLabel).grams * K.multiplier;

  const sheet = openSheet({
    title: entry ? '编辑份量' : '份量', cls: 'keypad', closeLabel: '取消', closeSide: 'start',
    build: () => {
      const g = grams(), n = food.nutritionPer100g;
      const mults = [...new Set([...MULTS, K.multiplier])].sort((a, b) => a - b);
      const set = (patch) => { Object.assign(K, patch); sheet.rerender(); };
      const key = (label, pressed, onClick, small) => h('button', { type: 'button', class: 'key', 'aria-pressed': String(pressed), onClick }, label, small && h('small', { class: 'num' }, small));
      return [
        // 表单卡片：食物与数值、餐次
        h('div', { class: 'kp-form' },
          h('div', { class: 'kp-head' }, emoji(food.emoji), h('span', { class: 'kp-name' }, food.name, gradeBadge(grade)),
            h('span', { 'aria-live': 'polite' }, amount(D.fmtSat((n.satFatG * g) / 100), 'kp-sat'))),
          h('p', { class: 'kp-detail num' }, `约 ${Math.round(g)} g · 胆固醇${D.fmtChol((n.cholesterolMg * g) / 100)} · 纤维${D.fmtFiber((n.solubleFiberG * g) / 100)} · ${D.transLabel(n.transFatG)}`)),
        h('div', { class: 'pad' }, segmented(MEAL_OPTIONS, K.meal, (m) => set({ meal: m }), '餐次')),
        // 停靠在底部的份量键盘：左侧三列白键，右侧一列功能键
        h('div', { class: 'kb' },
          h('div', { class: 'kb-main' },
            h('div', { class: 'kb-cap' }, '量具'),
            h('div', { class: 'kb-grid', role: 'group', 'aria-label': '量具' }, food.servings.map((x) => key(x.label, x.label === K.servingLabel, () => set({ servingLabel: x.label }), `${x.grams} g`))),
            h('div', { class: 'kb-cap' }, '倍数'),
            h('div', { class: 'kb-grid', role: 'group', 'aria-label': '倍数' }, mults.map((m) => key(multLabel(m), m === K.multiplier, () => set({ multiplier: m }))))),
          h('div', { class: 'kb-side' },
            h('button', { type: 'button', class: 'key fn', 'aria-label': '存为 One Touch', onClick: () => { toast(oneTouchResultText(addOneTouch({ foodId: food.id, ...K }))); refresh(); } }, icon('bolt', 20), h('small', null, 'One Touch')),
            h('button', { type: 'button', class: 'key go', onClick: submit }, entry ? '保存' : '记一笔'))),
      ];
    },
  });

  function submit() {
    sheet.close();
    haptic();
    if (entry) {
      updateEntry(entry, K, food);
      toast(`已更新${food.name}`);
    } else {
      const r = addEntry({ day: S.day, meal: K.meal, food, servingLabel: K.servingLabel, multiplier: K.multiplier, source: 'search' });
      toast(r.merged ? `${D.MEAL_LABEL[K.meal]}里已有${food.name}，已合并为 ${D.servingText(r.entry)}` : `已记入${D.MEAL_LABEL[K.meal]}：${food.name}`, { undo: r.undo });
    }
    onLogged?.(K.meal);
    refresh();
  }
  return sheet;
}

// ---------- One Touch ----------
export function openOneTouch() {
  let justLogged = null;
  const sheet = openSheet({
    title: 'One Touch',
    build: () => {
      const F = foods();
      const list = sortedOneTouch().filter((o) => F.has(o.foodId));
      const sugg = list.length < D.MAX_ONE_TOUCH ? D.oneTouchSuggestions(S.data.entries, list, { sinceDay: D.addDays(S.today, -30) }).filter((x) => F.has(x.foodId)) : [];
      return [
        h('p', { class: 'sheet-note' }, `点一下即入账，记在 ${D.dayLabel(S.day)}，3 秒内可撤销。`),
        list.length ? h('div', { class: 'ot-grid' }, list.map((o) => {
          const food = F.get(o.foodId);
          const sat = D.nutritionOf({ grams: (food.servings.find((x) => x.label === o.servingLabel)?.grams || 0) * o.multiplier }, food).sat;
          return h('button', {
            class: `ot-tile ${justLogged === o.id ? 'logged' : ''}`, type: 'button',
            'aria-label': `${food.name}，${D.servingText(o)}，${D.MEAL_LABEL[o.meal]}，饱和脂肪约 ${Math.round(sat)} 克。点按入账`,
            onClick: () => {
              const r = addEntry({ day: S.day, meal: o.meal, food, servingLabel: o.servingLabel, multiplier: o.multiplier, source: 'oneTouch' });
              haptic('success');
              justLogged = o.id;
              refresh();
              toast(r.merged ? `已合并到${D.MEAL_LABEL[o.meal]}的${food.name}` : `已记入${D.MEAL_LABEL[o.meal]}：${food.name}`, { undo: r.undo });
            },
          }, emoji(food.emoji), h('span', { class: 'ot-name' }, food.name), h('span', { class: 'ot-sub' }, `${D.servingText(o)} · ${D.MEAL_LABEL[o.meal]}`), h('span', { class: 'ot-sub num' }, justLogged === o.id ? '已记' : D.fmtSat(sat)));
        })) : h('p', { class: 'sheet-note' }, '还没有 One Touch。在份量键盘里点“存为 One Touch”，或从下面的高频食物里添加。'),
        sugg.length ? group({ title: '你的高频食物', footer: '根据最近 30 天的记录推荐。' }, sugg.map((x) => {
          const food = F.get(x.foodId);
          return row({
            emoji: food.emoji, title: food.name, sub: `${D.servingText(x)} · ${D.MEAL_LABEL[x.meal]} · ${x.count} 次`,
            trailing: h('button', { class: 'btn plain small', type: 'button', 'aria-label': `把${food.name}添加为 One Touch`, onClick: () => { toast(oneTouchResultText(addOneTouch(x))); refresh(); } }, '添加'),
          });
        })) : null,
        h('div', { class: 'btn-row' },
          h('span', { class: 'muted num' }, `${list.length} / ${D.MAX_ONE_TOUCH}`),
          h('button', { class: 'btn plain', type: 'button', onClick: () => { sheet.close(); openSettings(); } }, '管理')),
      ];
    },
  });
  return sheet;
}
