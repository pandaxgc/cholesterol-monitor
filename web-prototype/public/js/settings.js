// 设置、知识库、免责声明（PRD §5.5、§11）
import { h, icon, tile, group, row, segmented, toggle, emoji, openSheet, toast, confirmSheet, download } from './ui.js';
import { S, refresh, setPrefs, foods, setSettings, saveLimit, removeLimit, sortedOneTouch, removeOneTouch, moveOneTouchUp, resetData } from './store.js';
import * as D from '../shared/domain.js';
import { CATEGORIES, CATEGORY_BY_ID } from '../shared/foods.js';
import { confirmBlank } from './common.js';

export const DISCLAIMER = '本应用用于饮食记录与营养教育，不提供医疗诊断或治疗建议，不能替代医生的专业判断。血脂水平受遗传、体重、运动、药物、疾病等多种因素影响，饮食只是其中之一。请遵医嘱复查与治疗。';
const SESSION_URL = 'https://app.devin.ai/sessions/42ba9e75add849e58b5f7197bfe5c76b';

export function openDisclaimer(firstRun = false) {
  const sheet = openSheet({
    title: '免责声明', modal: firstRun,
    build: () => [
      h('p', { class: 'sheet-note strong' }, DISCLAIMER),
      firstRun && h('p', { class: 'sheet-note' }, '这是 PRD v0.2 的网页原型。食物营养数值是估算值，各项预算阈值尚未对照指南原文核实。'),
      firstRun && h('div', { class: 'btn-row' }, h('button', { class: 'btn', type: 'button', onClick: () => { setPrefs({ ack: true }); sheet.close(); } }, '我已阅读并了解')),
    ],
  });
}

function openKnowledge() {
  const p = (t) => h('p', { class: 'cell-text' }, t);
  openSheet({
    title: '知识库', tall: true,
    build: () => [
      group({ title: '“预算”和“余额”是什么' },
        p('这是记录用的比喻：把饱和脂肪当作每天有预算的货币，每一口是一笔支出。它帮你看清哪一笔最大，不代表身体里真的有一个余额。'),
        p('和记账不同的地方：营养量是估算的，误差可达三四成，所以界面不显示小数；纤维不能抵消饱和脂肪，所以两者分开显示，不算“净值”；血脂只在化验时更新，日常只看支出。')),
      group({ title: '四项指标', footer: '以上阈值尚待逐条对照指南原文核实，特别是可溶性纤维 10 g 与严格模式 11 g。' },
        row({ title: '饱和脂肪', sub: '主预算 · 标准 22 g（约 10% 能量，按 2000 kcal），严格 11 g', value: '支出' }),
        row({ title: '反式脂肪', sub: '零预算 · 尽量为 0，上限 2 g', value: '支出' }),
        row({ title: '膳食胆固醇', sub: '副预算 · 300 mg', value: '支出' }),
        row({ title: '可溶性膳食纤维', sub: '储蓄目标 · 至少 10 g，不与支出相抵', value: '储蓄' })),
      group({ title: '食物分级（每 100 g 可食部）' },
        row({ title: '友好', sub: '饱和脂肪 < 2 g' }),
        row({ title: '适量', sub: '饱和脂肪 2–5 g' }),
        row({ title: '留意', sub: '饱和脂肪 ≥ 5 g，或反式脂肪 > 0.1 g，或胆固醇 ≥ 100 mg' })),
      group({ title: '个人基线与离群日' },
        p('“日常水位”是你最近 14 个非离群日的均值，不足 5 天时不显示。聚餐、节日可以标记为离群日：照常记录和显示，但不计入水位，也不触发当日建议。')),
      group({ title: '每周次数限额' }, p('克数难估，次数好记。默认 4 条限额是产品建议值，不是指南原文，可以在设置中增删改。')),
      group({ title: '依据来源' },
        row({ title: '《中国血脂管理指南（2023 年）》' }), row({ title: '《中国居民膳食指南（2022）》' }),
        row({ title: '2018 AHA/ACC Guideline on the Management of Blood Cholesterol' }), row({ title: '《中国食物成分表》（第 6 版）', sub: '本原型的食物库是估算值，尚未使用该表数据' })),
    ],
  });
}

function exportData(kind) {
  const stamp = S.today;
  if (kind === 'csv') download(`血脂账本-饮食记录-${stamp}.csv`, D.toCSV(S.data.entries, foods()), 'text/csv;charset=utf-8');
  else download(`血脂账本-完整备份-${stamp}.json`, JSON.stringify({ exportedAt: new Date().toISOString(), note: '营养数值为估算值', ...S.data }, null, 2), 'application/json');
  toast('已开始下载');
}

function addLimitSheet() {
  const used = new Set(S.data.limits.map((l) => l.category));
  openSheet({
    title: '添加限额', tall: true,
    build: (sheet) => group({ footer: '选一个食物类别，默认每周 1 次，之后可以调整。' },
      CATEGORIES.filter((c) => !used.has(c.id)).map((c) => row({ emoji: c.emoji, title: c.name, onClick: () => { saveLimit({ category: c.id, maxCount: 1 }); sheet.close(); refresh(); } }))),
  });
}

export function openSettings() {
  openSheet({
    title: '设置', tall: true,
    build: () => {
      const st = S.data.settings, p = S.prefs, F = foods();
      const ots = sortedOneTouch();
      return [
        group({ title: '预算模式', footer: '标准：饱和脂肪每天 22 g（约 10% 能量）。严格：11 g（约 5% 能量）。阈值尚待对照指南原文核实。' },
          h('div', { class: 'cell-pad' }, segmented([['standard', '标准 22 g'], ['strict', '严格 11 g']], st.budgetMode, (v) => { setSettings({ budgetMode: v }); refresh(); }, '预算模式'))),

        group({ title: '每周限额', footer: '默认限额为产品建议值，不是指南原文。一餐内同一类别只计 1 次。' },
          S.data.limits.map((l) => {
            const cat = CATEGORY_BY_ID.get(l.category);
            const set = (n) => { saveLimit({ ...l, maxCount: n }); refresh(); };
            return row({
              emoji: cat?.emoji, title: cat?.name, sub: `每周 ${l.maxCount} 次`,
              trailing: h('div', { class: 'stepper' },
                h('button', { type: 'button', 'aria-label': `${cat?.name}减少一次`, disabled: l.maxCount <= 0, onClick: () => set(l.maxCount - 1) }, icon('minus', 16)),
                h('span', { class: 'num' }, l.maxCount),
                h('button', { type: 'button', 'aria-label': `${cat?.name}增加一次`, disabled: l.maxCount >= 14, onClick: () => set(l.maxCount + 1) }, icon('plus', 16)),
                h('button', { type: 'button', class: 'danger', 'aria-label': `删除${cat?.name}限额`, onClick: () => { removeLimit(l.id); refresh(); } }, icon('trash', 16))),
            });
          }),
          row({ lead: h('span', { class: 'row-icon' }, icon('plus', 18)), title: h('span', { class: 'accent-text' }, '添加限额'), onClick: addLimitSheet })),

        group({ title: `One Touch 管理（${ots.length} / ${D.MAX_ONE_TOUCH}）`, footer: '在份量键盘里点“存为 One Touch”可以新增。' },
          ots.length ? ots.map((o, i) => {
            const food = F.get(o.foodId);
            if (!food) return null;
            return row({
              emoji: food.emoji, title: food.name, sub: `${D.servingText(o)} · ${D.MEAL_LABEL[o.meal]}`,
              trailing: h('div', { class: 'stepper' },
                h('button', { type: 'button', 'aria-label': `${food.name}上移`, disabled: i === 0, onClick: () => { moveOneTouchUp(o.id); refresh(); } }, icon('arrowUp', 16)),
                h('button', { type: 'button', class: 'danger', 'aria-label': `删除 One Touch ${food.name}`, onClick: () => { removeOneTouch(o.id); refresh(); } }, icon('trash', 16))),
            });
          }) : row({ cls: 'guide', title: '还没有 One Touch' })),

        group({ title: '提醒', footer: '默认 21:30，可在 18:00–23:30 调整。网页原型不发送通知，这里只保存时间。' },
          h('label', { class: 'field' }, h('span', null, '晚间提醒时间'), h('input', { type: 'time', min: '18:00', max: '23:30', value: st.reminderTime, onChange: (e) => { const v = e.target.value; if (v >= '18:00' && v <= '23:30') setSettings({ reminderTime: v }); else { e.target.value = st.reminderTime; toast('提醒时间需在 18:00–23:30 之间'); } } }))),

        group({ title: '显示与反馈', footer: '这一组设置保存在当前设备的浏览器里。' },
          h('div', { class: 'cell-pad' }, h('div', { class: 'cell-label' }, '外观'), segmented([['system', '跟随系统'], ['light', '浅色'], ['dark', '深色']], p.appearance, (v) => setPrefs({ appearance: v }), '外观')),
          row({ title: '20:00 后自动深色', sub: '外观为“跟随系统”时生效', trailing: toggle(p.autoDark20, (v) => setPrefs({ autoDark20: v }), '20:00 后自动深色') }),
          h('div', { class: 'cell-pad' }, h('div', { class: 'cell-label' }, '食物 Emoji 大小'), segmented([[24, '小'], [28, '中'], [34, '大']], p.emojiSize, (v) => setPrefs({ emojiSize: v }), '食物 Emoji 大小')),
          h('div', { class: 'cell-pad' }, h('div', { class: 'cell-label' }, '惯用手（浮动按钮与键盘主按钮的位置）'), segmented([['left', '左手'], ['right', '右手']], p.hand, (v) => setPrefs({ hand: v }), '惯用手')),
          row({ title: '触感反馈', sub: '入账时轻震，仅部分设备支持', trailing: toggle(p.haptics, (v) => setPrefs({ haptics: v }), '触感反馈') })),

        group({ title: '数据', footer: st.demo ? '当前是示例数据。清空后从空白开始记录。' : '当前是你自己录入的数据。载入示例数据会覆盖现有记录。' },
          row({ lead: tile('download', 'blue'), title: '导出 CSV', sub: '饮食记录，便于给医生看', onClick: () => exportData('csv') }),
          row({ lead: tile('download', 'purple'), title: '导出 JSON', sub: '完整备份', onClick: () => exportData('json') }),
          st.demo
            ? row({ lead: tile('trash', 'red'), title: h('span', { class: 'danger' }, '清空示例数据，开始记录'), onClick: confirmBlank })
            : row({ lead: tile('today', 'gray'), title: '载入示例数据', onClick: () => confirmSheet({ title: '载入示例数据', message: '会删除现有的全部记录和化验结果，换成 90 天的演示数据。', confirmLabel: '载入示例', danger: true, onConfirm: async () => { try { await resetData('demo'); toast('已载入示例数据'); } catch (e) { toast(`载入失败：${e.message}`); } } }) })),

        group({ title: '说明' },
          row({ lead: tile('book', 'orange'), title: '知识库', sub: '指标含义、“预算”比喻的局限、依据来源', chevron: true, onClick: openKnowledge }),
          row({ lead: tile('shield', 'dark'), title: '免责声明', chevron: true, onClick: () => openDisclaimer(false) })),

        group({ title: '关于', footer: h('span', null, '这是网页原型，不含拍照识别、主屏小组件和系统通知。 ', h('a', { href: SESSION_URL, target: '_blank', rel: 'noopener' }, '想改点什么？到 Devin 会话里提')) },
          row({ title: '血脂账本', sub: 'cholesterol-monitor · PRD v0.2 原型', lead: emoji('📒') })),
      ];
    },
  });
}
