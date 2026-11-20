import { h, icon, navBar, confirmSheet, toast } from './ui.js';
import { S, resetData } from './store.js';

// 示例数据必须明确标注：提示卡样式
export function demoBanner() {
  if (!S.data.settings.demo) return null;
  return h('section', { class: 'tip', role: 'note' },
    h('div', { class: 'tip-head' }, h('span', null, '示例数据'), h('button', { class: 'tip-action', type: 'button', onClick: confirmBlank }, '清空，开始记录')),
    h('div', { class: 'tip-body' }, h('span', { class: 'tip-icon' }, icon('bubble', 30)), h('p', null, '这里的饮食记录和化验值是演示生成的，不是真实数据。')));
}

export function confirmBlank() {
  confirmSheet({
    title: '清空示例数据',
    message: '会删除全部饮食记录、化验结果、离群日标记和 One Touch（包括你在示例里添加的），限额恢复为 4 条默认值。之后从空白开始记录。',
    confirmLabel: '清空', danger: true,
    onConfirm: async () => { try { await resetData('blank'); toast('已清空，可以开始记录了'); } catch (e) { toast(`清空失败：${e.message}`); } },
  });
}

export function pageTitle(title, right) {
  return navBar({ title: h('h1', null, title), right });
}
