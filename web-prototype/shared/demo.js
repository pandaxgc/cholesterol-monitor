// 示例数据生成器：按日期确定性生成，所有条目带 demo:true。
import { addDays, weekday } from './domain.js';

function rng(seed) {
  let h = 2166136261;
  for (const c of seed) { h ^= c.charCodeAt(0); h = Math.imul(h, 16777619); }
  let a = h >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const pick = (r, options) => {
  let x = r() * options.reduce((s, o) => s + o[0], 0);
  for (const o of options) { x -= o[0]; if (x <= 0) return o[1]; }
  return options[options.length - 1][1];
};

const LUNCH = [
  [12, [['rice', '中碗'], ['braised_pork', '中碗'], ['stir_fried_greens', '小碗']]],
  [20, [['rice_bowl', '一份']]],
  [18, [['rice', '中碗'], ['kung_pao_chicken', '小碗'], ['stir_fried_greens', '小碗']]],
  [12, [['beef_noodle', '碗']]],
  [15, [['rice', '中碗'], ['tomato_egg', '小碗'], ['broccoli', '小碗']]],
  [10, [['dumplings', '一盘']]],
  [8, [['rice', '中碗'], ['yuxiang_pork', '小碗']]],
  [5, [['burger', '个'], ['french_fries', '中份']]],
];
const DINNER_MAIN = [
  [20, ['steamed_fish', '手掌大小']], [18, ['pepper_pork', '小碗']], [15, ['mapo_tofu', '中碗']],
  [12, ['spare_ribs', '小碗']], [10, ['chicken_breast', '手掌大小']], [10, ['pork_belly', '小碗']],
  [8, ['sour_fish', '小碗']], [4, ['pork_liver', '小碗']], [3, ['shrimp', '小碗']],
];
const DINNER_VEG = [[50, ['stir_fried_greens', '小碗']], [25, ['broccoli', '小碗']], [15, ['cucumber_salad', '小碗']], [10, null]];
const OUTING = [[45, ['hotpot_tallow', '正常']], [35, ['bbq', '正常']], [20, ['banquet', '正常']]];

// mode: 'full' 全天 | 'partial' 只有早餐与午餐（当天晚间待补记）| 'rest' 只补晚餐与加餐
export function demoDay(day, foods, mode = 'full') {
  const r = rng(`demo:${day}`);
  const wd = weekday(day);
  const weekend = wd === 0 || wd === 6;
  const plan = { breakfast: [], lunch: [], dinner: [], snack: [] };
  const src = { breakfast: 'prefill', lunch: 'search', dinner: 'search', snack: 'oneTouch' };

  const b = r();
  if (b < 0.72) plan.breakfast.push(['boiled_egg', '个'], ['oat_porridge', '中碗']);
  else if (b < 0.82) plan.breakfast.push(['pork_bun', '个', 2], ['soy_milk', '杯']);
  else if (b < 0.9) plan.breakfast.push(['youtiao', '根'], ['soy_milk', '杯']);
  else if (b < 0.96) plan.breakfast.push(['whole_wheat_bread', '片', 2], ['whole_milk', '杯']);

  plan.lunch.push(...pick(r, LUNCH));

  const outing = weekend && r() < 0.22;
  if (outing) plan.dinner.push(pick(r, OUTING));
  else {
    if (r() < 0.85) plan.dinner.push(['rice', r() < 0.5 ? '小碗' : '中碗']);
    plan.dinner.push(pick(r, DINNER_MAIN));
    const veg = pick(r, DINNER_VEG);
    if (veg) plan.dinner.push(veg);
  }

  const s = r();
  if (s < 0.3) plan.snack.push(['apple', '个']);
  else if (s < 0.42) plan.snack.push(['yogurt', '小盒']);
  else if (s < 0.5) plan.snack.push(['walnut', '一小把']);
  else if (s < 0.6) plan.snack.push(['bubble_tea', '中杯']);
  else if (s < 0.66) plan.snack.push(['biscuit', '小包']);
  else if (s < 0.69) plan.snack.push(['cream_cake', '块']);

  if (mode === 'partial') {
    plan.breakfast = [['boiled_egg', '个'], ['oat_porridge', '中碗']];
    plan.lunch = [['braised_pork', '中碗'], ['rice', '中碗']];
    plan.dinner = []; plan.snack = [];
  } else if (mode === 'rest') {
    plan.breakfast = []; plan.lunch = [];
  }

  const entries = [];
  let i = 0;
  for (const meal of Object.keys(plan)) {
    for (const [foodId, servingLabel, multiplier = 1] of plan[meal]) {
      const food = foods.get(foodId);
      const serving = food?.servings.find((x) => x.label === servingLabel);
      if (!serving) throw new Error(`demo: 未知量具 ${foodId}/${servingLabel}`);
      entries.push({
        id: `demo_${day}_${meal}_${i}`, day, meal, foodId, servingLabel, multiplier,
        grams: serving.grams * multiplier, photoRef: null, source: src[meal],
        createdAt: `${day}T21:${String(40 + (i % 15)).padStart(2, '0')}:00+08:00`, demo: true,
      });
      i++;
    }
  }
  return { entries, outlier: mode !== 'partial' && outing };
}

export function demoLabs(today) {
  return [
    { id: 'lab_demo_1', date: addDays(today, -88), tc: 6.1, ldlC: 4.1, hdlC: 1.1, tg: 1.9, unit: 'mmol/L', note: '示例', demo: true },
    { id: 'lab_demo_2', date: addDays(today, -5), tc: 5.6, ldlC: 3.6, hdlC: 1.2, tg: 1.6, unit: 'mmol/L', note: '示例', demo: true },
  ];
}

export const DEMO_ONE_TOUCH = [
  { id: 'ot_demo_1', foodId: 'boiled_egg', servingLabel: '个', multiplier: 1, meal: 'breakfast', sortOrder: 0 },
  { id: 'ot_demo_2', foodId: 'oat_porridge', servingLabel: '中碗', multiplier: 1, meal: 'breakfast', sortOrder: 1 },
  { id: 'ot_demo_3', foodId: 'rice', servingLabel: '中碗', multiplier: 1, meal: 'lunch', sortOrder: 2 },
  { id: 'ot_demo_4', foodId: 'rice', servingLabel: '小碗', multiplier: 1, meal: 'dinner', sortOrder: 3 },
  { id: 'ot_demo_5', foodId: 'apple', servingLabel: '个', multiplier: 1, meal: 'snack', sortOrder: 4 },
  { id: 'ot_demo_6', foodId: 'soy_milk', servingLabel: '杯', multiplier: 1, meal: 'breakfast', sortOrder: 5 },
];

export const DEMO_DAYS = 90;
