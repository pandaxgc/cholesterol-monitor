// 化验：血脂四项录入与对照（PRD §5.4）
import { h, s, group, row, tag, amount, openSheet, toast, confirmSheet } from './ui.js';
import { S, refresh, foods, outliers, saveLab, removeLab } from './store.js';
import * as D from '../shared/domain.js';
import { demoBanner, pageTitle } from './common.js';

export const LAB_NOTE = '血脂受遗传、药物、体重等多种因素影响，本页仅作记录对照，不构成因果结论。';
const FIELDS = [['tc', 'TC', '总胆固醇'], ['ldlC', 'LDL-C', '低密度脂蛋白胆固醇'], ['hdlC', 'HDL-C', '高密度脂蛋白胆固醇'], ['tg', 'TG', '甘油三酯']];
const fmt = (v) => (v == null ? '—' : v.toFixed(1));

function spark(labs, key) {
  const pts = labs.map((l, i) => ({ i, v: l[key] })).filter((p) => p.v != null);
  const W = 120, H = 34, P = 5;
  if (!pts.length) return s('svg', { width: W, height: H, 'aria-hidden': 'true' });
  const min = Math.min(...pts.map((p) => p.v)), max = Math.max(...pts.map((p) => p.v));
  const span = max - min || 1;
  const x = (i) => (labs.length > 1 ? P + (i / (labs.length - 1)) * (W - 2 * P) : W / 2);
  const y = (v) => (max === min ? H / 2 : P + (1 - (v - min) / span) * (H - 2 * P));
  return s('svg', { class: 'chart spark', viewBox: `0 0 ${W} ${H}`, width: W, height: H, 'aria-hidden': 'true' },
    pts.length > 1 && s('polyline', { class: 'spend', points: pts.map((p) => `${x(p.i).toFixed(1)},${y(p.v).toFixed(1)}`).join(' ') }),
    pts.map((p) => s('circle', { class: 'dot', cx: x(p.i), cy: y(p.v), r: 2.6 })));
}

function labForm(lab) {
  const v = lab ? { ...lab } : { date: S.today, tc: null, ldlC: null, hdlC: null, tg: null, note: '' };
  const err = h('p', { class: 'form-error', role: 'alert' });
  const num = (key) => h('input', { type: 'number', inputmode: 'decimal', step: '0.01', min: '0', max: '30', placeholder: 'mmol/L', value: v[key] ?? '', 'aria-label': key, onInput: (e) => { v[key] = e.target.value === '' ? null : Number(e.target.value); } });
  const sheet = openSheet({
    title: lab ? '编辑化验结果' : '录入化验结果', tall: true,
    build: () => [
      group({ footer: '单位 mmol/L。化验单上没有的项目可以留空。' },
        h('label', { class: 'field' }, h('span', null, '检测日期'), h('input', { type: 'date', max: S.today, value: v.date, onInput: (e) => { v.date = e.target.value; } })),
        FIELDS.map(([key, short, long]) => h('label', { class: 'field' }, h('span', null, short, h('small', null, long)), num(key))),
        h('label', { class: 'field' }, h('span', null, '备注'), h('input', { type: 'text', maxlength: 40, placeholder: '例如 体检中心', value: v.note || '', onInput: (e) => { v.note = e.target.value; } }))),
      err,
      h('div', { class: 'btn-row' },
        lab && h('button', { class: 'btn secondary danger', type: 'button', onClick: () => confirmSheet({ title: '删除这次化验结果', message: `${D.dayLabel(lab.date)}的化验结果会被删除。`, confirmLabel: '删除', danger: true, onConfirm: () => { removeLab(lab.id); sheet.close(); refresh(); toast('已删除'); } }) }, '删除'),
        h('button', {
          class: 'btn', type: 'button', onClick: () => {
            const vals = FIELDS.map(([k]) => v[k]).filter((x) => x != null);
            if (!/^\d{4}-\d{2}-\d{2}$/.test(v.date || '') || v.date > S.today) { err.textContent = '请选择检测日期，不能晚于今天。'; return; }
            if (!vals.length) { err.textContent = '至少填写一项化验值。'; return; }
            if (vals.some((x) => !(x > 0 && x <= 30))) { err.textContent = '化验值应在 0 到 30 mmol/L 之间，请核对。'; return; }
            const { demo, ...rest } = v;
            saveLab({ ...rest, note: (v.note || '').trim() });
            sheet.close(); refresh(); toast('已保存化验结果');
          },
        }, '保存')),
    ],
  });
}

function summaryGroup(title, from, to) {
  const sum = D.intervalSummary(S.data.entries, foods(), S.data.limits, outliers(), from, to);
  if (!sum) return group({ title }, row({ cls: 'guide', title: '这段时间没有饮食记录' }));
  return group({ title, footer: `${sum.recordedDays} 个记录日（不含离群日）的同期饮食均值。` },
    row({ title: '饱和脂肪日均', value: D.fmtSat(sum.satMean) }),
    row({ title: '纤维达标天数', value: `约 ${D.roundPct5(sum.fiberShare)}%` }),
    row({ title: '限额执行', value: `${sum.okWeeks} / ${sum.weeks} 周在限额内` }));
}

export function renderLabs() {
  const labs = [...S.data.labs].sort((a, b) => a.date.localeCompare(b.date));
  const last = labs[labs.length - 1], prev = labs[labs.length - 2];
  const intervals = [];
  for (let i = labs.length - 1; i >= 1; i--) intervals.push(summaryGroup(`${D.dayLabel(labs[i - 1].date)} 至 ${D.dayLabel(labs[i].date)}`, labs[i - 1].date, labs[i].date));
  return [
    pageTitle('化验'),
    demoBanner(),
    h('p', { class: 'disclaimer' }, LAB_NOTE),
    h('div', { class: 'btn-row' }, h('button', { class: 'btn', type: 'button', onClick: () => labForm(null) }, '录入化验结果')),
    labs.length ? group({ title: '历次结果', headline: true, right: 'mmol/L', footer: labs.length > 1 ? `折线为 ${labs.length} 次结果的走势，右侧是最近一次与上一次的数值。` : '再录入一次后，这里会画出走势。' },
      FIELDS.map(([key, short, long]) => row({
        title: short, sub: long, lead: null,
        trailing: h('div', { class: 'spark-cell', role: 'img', 'aria-label': `${long}：${labs.map((l) => `${D.dayLabel(l.date)} ${fmt(l[key])}`).join('，')}` },
          spark(labs, key), amount(prev ? `${fmt(prev[key])} → ${fmt(last[key])}` : fmt(last[key]), 'spark-val muted')),
      }))) : h('p', { class: 'sheet-note' }, '还没有化验结果。拿到化验单后录入血脂四项，这里会并列显示同期的饮食均值。'),
    last && summaryGroup(`${D.dayLabel(last.date)} 至今`, last.date, D.addDays(S.today, 1)),
    intervals,
    labs.length ? group({ title: '记录', headline: true }, [...labs].reverse().map((l) => row({
      title: h('span', { class: 'num' }, l.date), badge: l.demo && tag('示例'), sub: [FIELDS.map(([k, short]) => `${short} ${fmt(l[k])}`).join(' · '), l.note && !l.demo ? ` · ${l.note}` : ''].join(''),
      chevron: true, onClick: () => labForm(l),
    }))) : null,
  ];
}
