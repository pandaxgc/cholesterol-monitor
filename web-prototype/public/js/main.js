import { h, icon, toast, rerenderSheets } from './ui.js';
import { S, load, onChange, refresh, applyTheme } from './store.js';
import { renderToday } from './today.js';
import { renderLists } from './lists.js';
import { renderAnalysis } from './analysis.js';
import { renderLabs } from './labs.js';
import { openAddPanel, openOneTouch } from './add.js';
import { openDisclaimer } from './settings.js';
import { logicalDay } from '../shared/domain.js';

const TABS = [['today', '今日', 'tabToday', renderToday], ['lists', '清单', 'tabList', renderLists], ['analysis', '分析', 'tabChart', renderAnalysis], ['labs', '化验', 'tabFlask', renderLabs]];
const view = document.getElementById('view');

function append(el, kids) {
  for (const k of [kids].flat(Infinity)) if (k != null && k !== false) el.append(k);
}

function render() {
  const tab = TABS.find((t) => t[0] === S.tab) || TABS[0];
  view.replaceChildren();
  append(view, tab[3]());

  document.getElementById('tabbar').replaceChildren(...TABS.map(([id, label, ic]) => h('button', {
    type: 'button', 'aria-current': id === S.tab ? 'page' : null,
    onClick: () => { if (S.tab !== id) { S.tab = id; refresh(); window.scrollTo(0, 0); } },
  }, icon(ic, 24), h('span', null, label))));

  const fabs = document.getElementById('fabs');
  fabs.replaceChildren();
  if (S.tab === 'today') {
    append(fabs, [
      h('button', { type: 'button', class: 'fab', 'aria-label': '搜索食物', onClick: () => openAddPanel({ focusSearch: true }) }, icon('search', 24)),
      h('button', { type: 'button', class: 'fab', 'aria-label': 'One Touch 一触即记', onClick: () => openOneTouch() }, icon('bolt', 24)),
      h('button', { type: 'button', class: 'fab', 'aria-label': '添加记录', onClick: () => openAddPanel() }, icon('plus', 24)),
    ]);
  }
}

onChange(() => { render(); rerenderSheets(); });
S.onError = (e) => toast(`保存失败，已重新载入：${e.message}`, { ms: 5000 });

async function reload() {
  try { await load(); refresh(); } catch (e) { toast(`载入失败：${e.message}`, { ms: 5000 }); }
}

applyTheme();
view.append(h('p', { class: 'loading' }, '正在载入…'));
try {
  await load();
  render();
  if (!S.prefs.ack) openDisclaimer(true);
} catch (e) {
  view.replaceChildren(h('div', { class: 'loading' }, h('p', null, `载入失败：${e.message}`), h('button', { class: 'btn', type: 'button', onClick: () => location.reload() }, '重试')));
}

// 回到前台时同步；跨过 04:00 或 20:00 时更新日期与外观
document.addEventListener('visibilitychange', () => { if (!document.hidden && S.data) reload(); });
setInterval(() => { applyTheme(); if (S.data && !document.hidden && S.today !== logicalDay()) reload(); }, 60000);
