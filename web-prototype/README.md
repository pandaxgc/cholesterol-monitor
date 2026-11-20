# 血脂账本（app-prd）

cholesterol-monitor PRD v0.2 的可点击 Web 原型，作为 Devin App `app-prd` 提供服务。

- 运行：`PORT=3000 npm run start`（Node ≥ 22.13，无第三方依赖）
- 测试：`npm test`（领域逻辑单元测试）
- 数据：SQLite，默认存放在 `~/app-prd-data/app.db`（可用 `DATA_DIR` 修改），不在应用目录内
- `shared/`：纯函数领域逻辑、食物库（估算值，未核实）、示例数据生成器，前后端共用
- `public/`：原生 ES 模块前端，无构建步骤

未包含：拍照识别、主屏小组件、系统通知、Apple Watch 与快捷指令入口。

字体：`public/fonts/nunito-800-digits.woff2` 是 Nunito（SIL Open Font License 1.1）的 0–9 子集，只用于余额大数字的圆体回退。
