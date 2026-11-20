// 轻量 DOM 工具与通用组件（原生分组列表、底部面板、撤销条）。
import { GRADE_LABEL } from '../shared/domain.js';

function append(el, kids) {
  for (const k of kids.flat(Infinity)) {
    if (k == null || k === false || k === true) continue;
    el.append(k instanceof Node ? k : document.createTextNode(String(k)));
  }
  return el;
}
function make(el, attrs, kids) {
  for (const [k, v] of Object.entries(attrs || {})) {
    if (v == null || v === false) continue;
    if (k.startsWith('on')) el.addEventListener(k.slice(2).toLowerCase(), v);
    else if (k === 'class') el.setAttribute('class', v);
    else if (k === 'style' && typeof v === 'object') Object.assign(el.style, v);
    else if (k === 'value' || k === 'checked' || k === 'disabled') el[k] = v;
    else el.setAttribute(k, v === true ? '' : v);
  }
  return append(el, kids);
}
export const h = (tag, attrs, ...kids) => make(document.createElement(tag), attrs, kids);
export const s = (tag, attrs, ...kids) => make(document.createElementNS('http://www.w3.org/2000/svg', tag), attrs, kids);

const ICONS = {
  search: 'M11 4a7 7 0 1 0 0 14a7 7 0 0 0 0-14zM16.5 16.5L21 21',
  bolt: 'M13 2L4.5 13.5H11L10 22l8.5-11.5H12L13 2z',
  plus: 'M12 5v14M5 12h14',
  minus: 'M5 12h14',
  person: 'M12 12a4 4 0 1 0 0-8a4 4 0 0 0 0 8zM4.5 20.5c1.2-3.6 4.1-5.5 7.5-5.5s6.3 1.9 7.5 5.5',
  chevronRight: 'M9 5l7 7-7 7',
  chevronLeft: 'M15 5l-7 7 7 7',
  ellipsis: 'M5 12h.01M12 12h.01M19 12h.01',
  check: 'M5 12.5l4.5 4.5L19 7.5',
  trash: 'M4 7h16M9 7V4.5h6V7M6.5 7l1 13h9l1-13M10 11v5.5M14 11v5.5',
  copy: 'M9 9h10.5v11.5H9zM5 15H4.5V3.5H15V5',
  pencil: 'M4 20l1-4.5L16.5 4l3.5 3.5L8.5 19 4 20zM14 6.5l3.5 3.5',
  close: 'M6 6l12 12M18 6L6 18',
  today: 'M6 3.5h12a1 1 0 0 1 1 1v15a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1v-15a1 1 0 0 1 1-1zM8.5 8h7M8.5 12h7M8.5 16h4',
  list: 'M8.5 6.5h11M8.5 12h11M8.5 17.5h11M4.5 6.5h.01M4.5 12h.01M4.5 17.5h.01',
  chart: 'M4.5 19.5V5M4.5 19.5h15M8 15.5l3.5-4 3 2.5 4.5-6',
  flask: 'M9.5 3.5h5M10.5 3.5v6L5 19a1.2 1.2 0 0 0 1 1.8h12a1.2 1.2 0 0 0 1-1.8l-5.5-9.5v-6M7.8 15h8.4',
  download: 'M12 4v11M7.5 11l4.5 4.5 4.5-4.5M5 19.5h14',
  info: 'M12 21a9 9 0 1 0 0-18a9 9 0 0 0 0 18zM12 11v5.5M12 7.8h.01',
  arrowUp: 'M12 19V5M6 11l6-6 6 6',
  chevronDown: 'M6 9l6 6 6-6',
  eye: 'M2.5 12s3.5-6.5 9.5-6.5S21.5 12 21.5 12s-3.5 6.5-9.5 6.5S2.5 12 2.5 12zM12 14.75a2.75 2.75 0 1 0 0-5.5a2.75 2.75 0 0 0 0 5.5z',
  gauge: 'M4 17a8 8 0 1 1 16 0M12 17l4-5.5',
  fork: 'M7 3v7.5a2 2 0 0 0 2 2V21M5 3v5M9 3v5M16.5 3c-1.8 1.6-2.5 3.6-2.5 6s.8 3.6 2.5 4.2V21',
  alert: 'M12 4l9 15.5H3L12 4zM12 10v4.5M12 17.2h.01',
  calendar: 'M5 5.5h14a1 1 0 0 1 1 1V19a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V6.5a1 1 0 0 1 1-1zM4 10h16M8 3.5v4M16 3.5v4',
  book: 'M5 4.5h10.5a3 3 0 0 1 3 3V20H8a3 3 0 0 1-3-3V4.5zM5 17a3 3 0 0 1 3-3h10.5',
  shield: 'M12 3l7.5 3v5.5c0 4.6-3 8.2-7.5 9.5-4.5-1.3-7.5-4.9-7.5-9.5V6L12 3z',
  // 实心图标（Tab Bar 与提示卡）
  tabToday: 'M6 3h12a2.5 2.5 0 0 1 2.5 2.5v13A2.5 2.5 0 0 1 18 21H6a2.5 2.5 0 0 1-2.5-2.5v-13A2.5 2.5 0 0 1 6 3zm2 10.25a.75.75 0 0 0 0 1.5h8a.75.75 0 0 0 0-1.5H8zm0 3a.75.75 0 0 0 0 1.5h5a.75.75 0 0 0 0-1.5H8zM8 7a1 1 0 0 0-1 1v2a1 1 0 0 0 1 1h8a1 1 0 0 0 1-1V8a1 1 0 0 0-1-1H8z',
  tabList: 'M4 5.5a1.5 1.5 0 1 1 3 0a1.5 1.5 0 0 1-3 0zM9 4.25h10.5a1.25 1.25 0 0 1 0 2.5H9a1.25 1.25 0 0 1 0-2.5zM4 12a1.5 1.5 0 1 1 3 0a1.5 1.5 0 0 1-3 0zM9 10.75h10.5a1.25 1.25 0 0 1 0 2.5H9a1.25 1.25 0 0 1 0-2.5zM4 18.5a1.5 1.5 0 1 1 3 0a1.5 1.5 0 0 1-3 0zM9 17.25h10.5a1.25 1.25 0 0 1 0 2.5H9a1.25 1.25 0 0 1 0-2.5z',
  tabChart: 'M4.5 10.5h2a1 1 0 0 1 1 1V17h-4v-5.500a1 1 0 0 1 1-1zM9.500 5h2a1 1 0 0 1 1 1v11h-4V6a1 1 0 0 1 1-1zM14.5 8.5h2a1 1 0 0 1 1 1V17h-4V9.500a1 1 0 0 1 1-1zM19 12h1a1 1 0 0 1 1 1v4h-3v-4a1 1 0 0 1 1-1zM3 18.75h18.5a.75.75 0 0 1 0 1.5H3a.75.75 0 0 1 0-1.5z',
  tabFlask: 'M9 2.5h6a1 1 0 0 1 0 2h-.5v4.700l5.100 8.600A2.100 2.100 0 0 1 17.800 21H6.200a2.100 2.100 0 0 1-1.800-3.200l5.100-8.600V4.500H9a1 1 0 0 1 0-2zm2.500 2v5.250L9.200 13.600h5.600l-2.300-3.850V4.500h-1z',
  bubble: 'M5 4h14a2.5 2.5 0 0 1 2.5 2.5v8A2.5 2.5 0 0 1 19 17h-8l-4.500 3.500V17H5a2.500 2.500 0 0 1-2.500-2.500v-8A2.500 2.500 0 0 1 5 4zm3 4.250a.75.75 0 0 0 0 1.500h8a.75.75 0 0 0 0-1.500H8zm0 3.500a.75.75 0 0 0 0 1.500h5a.75.75 0 0 0 0-1.500H8z',
};
const FILLED = new Set(['tabToday', 'tabList', 'tabChart', 'tabFlask', 'bubble']);
export function icon(name, size = 22) {
  if (FILLED.has(name)) return s('svg', { class: 'icon', viewBox: '0 0 24 24', width: size, height: size, fill: 'currentColor', 'aria-hidden': 'true' }, s('path', { d: ICONS[name], 'fill-rule': 'evenodd' }));
  return s('svg', { class: 'icon', viewBox: '0 0 24 24', width: size, height: size, fill: 'none', stroke: 'currentColor', 'stroke-width': name === 'ellipsis' ? 3 : 1.8, 'stroke-linecap': 'round', 'stroke-linejoin': 'round', 'aria-hidden': 'true' },
    s('path', { d: ICONS[name] }));
}

// Emoji 是装饰性元素：读屏读食物名，不读 Emoji
export const emoji = (e) => h('span', { class: 'emoji', 'aria-hidden': 'true' }, e);

// 等级同时用图形和文字表达：实心圆点 / 半环 / 空心圆环
export function gradeBadge(grade) {
  const shape = grade === 'A' ? s('circle', { cx: 6, cy: 6, r: 4.5, fill: 'currentColor' })
    : grade === 'B' ? s('path', { d: 'M1.5 6a4.5 4.5 0 0 1 9 0', fill: 'none', stroke: 'currentColor', 'stroke-width': 1.8, 'stroke-linecap': 'round' })
      : s('circle', { cx: 6, cy: 6, r: 4, fill: 'none', stroke: 'currentColor', 'stroke-width': 1.8 });
  return h('span', { class: `grade grade-${grade}` }, s('svg', { viewBox: '0 0 12 12', width: 11, height: 11, 'aria-hidden': 'true' }, shape), GRADE_LABEL[grade]);
}

// 数值排版：数字保持主色与等宽，“约”和单位降一级。没有数字的文本原样返回
export function amount(text, cls = '') {
  if (typeof text !== 'string' || !/\d/.test(text)) return text;
  return h('span', { class: `amt ${cls}` }, text.split(/(\d+(?:\.\d+)?)/).map((p, i) => p && h('span', { class: i % 2 ? 'n' : 'u' }, p)));
}

// 彩色圆角方块图标（设置与功能行）
export const tile = (name, tone = 'accent') => h('span', { class: `tile ${tone}` }, icon(name, 18));

// 顶部导航：居中的行内标题，两侧是圆形玻璃按钮
export function navBar({ left, title, right }) {
  return h('header', { class: 'nav' }, h('div', { class: 'nav-side' }, left), h('div', { class: 'nav-title' }, title), h('div', { class: 'nav-side end' }, right));
}
export const glassBtn = (name, label, onClick, attrs = {}) => h('button', { class: 'glass-btn', type: 'button', 'aria-label': label, onClick, ...attrs }, icon(name, 20));

// 灰色小标题在上、粗体数值在下的两列统计格
export function statGrid(items) {
  return h('dl', { class: 'stats' }, items.filter(Boolean).map((i) => h(i.onClick ? 'button' : 'div', { class: `stat ${i.cls || ''}`, type: i.onClick ? 'button' : null, onClick: i.onClick },
    h('dt', null, i.label), h('dd', { class: 'num' }, amount(i.value), i.note && h('small', null, i.note)))));
}

export const tag = (text, cls = '') => h('span', { class: `tag ${cls}` }, text);

// 原生分组列表
export function group({ title, right, footer, headline = false }, ...rows) {
  const items = rows.flat(Infinity).filter(Boolean);
  return h('section', { class: 'group' },
    (title || right) && h('div', { class: `group-head${headline ? ' headline' : ''}` }, h('h2', null, title), right && amount(right)),
    items.length ? h('ul', { class: 'list' }, items.map((r) => h('li', null, r))) : null,
    footer && h('p', { class: 'group-foot' }, footer));
}

// 列表行。有 onClick 时主体是按钮；trailing 是行尾的独立控件
export function row({ emoji: e, lead, title, badge, detail, sub, value, chevron, onClick, trailing, cls = '', label, valueCls = '' }) {
  const body = [
    e ? emoji(e) : lead,
    h('span', { class: 'row-main' },
      h('span', { class: 'row-title' }, title, detail && h('span', { class: 'row-detail' }, detail), badge),
      sub && h('span', { class: 'row-sub' }, sub)),
    value != null && h('span', { class: `row-value num ${valueCls}` }, amount(value)),
    chevron && h('span', { class: 'chev' }, icon('chevronRight', 16)),
  ];
  const main = onClick ? h('button', { class: 'row-btn', type: 'button', onClick, 'aria-label': label }, body) : h('div', { class: 'row-btn', 'aria-label': label, role: label ? 'group' : null }, body);
  return h('div', { class: `row ${cls}` }, main, trailing);
}

export function segmented(options, value, onChange, label) {
  return h('div', { class: 'seg', role: 'group', 'aria-label': label },
    options.map(([v, text]) => h('button', { type: 'button', 'aria-pressed': String(v === value), onClick: () => onChange(v) }, text)));
}

export function toggle(checked, onChange, label) {
  return h('button', { type: 'button', class: 'switch', role: 'switch', 'aria-checked': String(!!checked), 'aria-label': label, onClick: () => onChange(!checked) }, h('span'));
}

export function haptic(kind = 'light') {
  try {
    if (JSON.parse(localStorage.getItem('prefs') || '{}').haptics === false) return;
    navigator.vibrate?.(kind === 'success' ? [12, 40, 18] : 10);
  } catch { /* 不支持触感的设备直接忽略 */ }
}

// ---------- 底部面板 ----------
const stack = [];
const host = () => document.getElementById('sheets');

export function openSheet({ title, build, update, tall = false, modal = false, onClose, cls = '', closeLabel = '完成', closeSide = 'end' }) {
  const body = h('div', { class: 'sheet-body' });
  const sheet = {
    body,
    close() {
      const i = stack.indexOf(sheet);
      if (i < 0) return;
      stack.splice(i, 1);
      // 退出动画：沿进入的路径滑回去，结束后再移除
      wrap.dataset.closing = '';
      wrap.inert = true;
      setTimeout(() => wrap.remove(), 240);
      onClose?.();
      (stack[stack.length - 1]?.panel || document.getElementById('view')).focus?.({ preventScroll: true });
    },
    rerender() {
      if (update) return update(sheet);
      const top = body.scrollTop;
      body.replaceChildren();
      append(body, [build(sheet)]);
      body.scrollTop = top;
    },
  };
  const panel = h('div', { class: `sheet ${tall ? 'tall' : ''} ${cls}`, role: 'dialog', 'aria-modal': 'true', 'aria-label': title, tabindex: '-1' },
    h('div', { class: 'grabber', 'aria-hidden': 'true' }),
    h('div', { class: 'sheet-head' },
      h('h2', null, title),
      !modal && h('button', { class: `glass-pill ${closeSide}`, type: 'button', onClick: () => sheet.close() }, closeLabel)),
    body);
  const wrap = h('div', { class: 'sheet-wrap' }, h('div', { class: 'sheet-overlay', onClick: () => !modal && sheet.close() }), panel);
  sheet.panel = panel; sheet.modal = modal;
  append(body, [build(sheet)]);
  host().append(wrap);
  stack.push(sheet);
  panel.focus({ preventScroll: true });
  return sheet;
}
export const rerenderSheets = () => [...stack].forEach((x) => x.rerender());
export const closeAllSheets = () => [...stack].reverse().forEach((x) => x.close());
document.addEventListener('keydown', (e) => {
  const top = stack[stack.length - 1];
  if (e.key === 'Escape' && top && !top.modal) top.close();
});

export function actionSheet({ title, note, actions }) {
  return openSheet({
    title,
    build: (sheet) => [
      note && h('p', { class: 'sheet-note' }, note),
      group({}, (typeof actions === 'function' ? actions(sheet) : actions).filter(Boolean).map((a) => a.node || row({
        lead: a.icon && h('span', { class: `row-icon ${a.danger ? 'danger' : ''}` }, icon(a.icon, 20)),
        title: h('span', { class: a.danger ? 'danger' : '' }, a.label), sub: a.sub,
        onClick: () => { if (!a.keepOpen) sheet.close(); a.onClick(sheet); },
      }))),
    ],
  });
}

export function confirmSheet({ title, message, confirmLabel, danger, onConfirm }) {
  return openSheet({
    title,
    build: (sheet) => [
      h('p', { class: 'sheet-note' }, message),
      h('div', { class: 'btn-row' },
        h('button', { class: 'btn secondary', type: 'button', onClick: () => sheet.close() }, '取消'),
        h('button', { class: `btn ${danger ? 'warn' : ''}`, type: 'button', onClick: () => { sheet.close(); onConfirm(); } }, confirmLabel)),
    ],
  });
}

// ---------- 撤销条 ----------
let toastTimer = null;
export function toast(text, { undo, ms = 3000 } = {}) {
  const el = document.getElementById('toast');
  clearTimeout(toastTimer);
  el.replaceChildren(h('div', { class: 'toast' }, h('span', null, text),
    undo && h('button', { class: 'btn plain', type: 'button', onClick: () => { el.replaceChildren(); undo(); } }, '撤销')));
  toastTimer = setTimeout(() => el.replaceChildren(), ms);
}

export function download(filename, text, type) {
  const url = URL.createObjectURL(new Blob([text], { type }));
  const a = h('a', { href: url, download: filename });
  document.body.append(a); a.click(); a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
