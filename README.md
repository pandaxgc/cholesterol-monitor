# cholesterol-monitor（血脂账本）

饱和脂肪预算记账式的血脂管理 App。

- `docs/PRD.md`：产品需求文档 v0.2。
- `docs/reference/`：MoneyThings 参考截图（`IMG_*.PNG`）与网页原型截图（`web-*`）。
- `web-prototype/`：已有的网页原型（Node，零依赖），作为原生 iOS 版的移植参考：领域逻辑、食物库、演示数据、界面与设计令牌。

- `CholesterolMonitor.xcodeproj` / `CholesterolMonitor/`：原生 iOS App（SwiftUI + SwiftData + Swift Charts，iOS 26 起，无第三方依赖）。
- `Packages/LipidDomain/`：领域逻辑 Swift Package（预算、分级、聚合、基线、建议、食物库、示例数据）及单元测试。

## 在自己的 iPhone 上运行

需要：装有 Xcode 26.3 或更新版本的 Mac，系统为 iOS 26 或更新版本的 iPhone（例如 iPhone 17 Pro），一个 Apple ID（免费账号即可）。

1. 克隆仓库后，双击打开根目录的 `CholesterolMonitor.xcodeproj`。
2. 首次使用 Apple ID：Xcode → Settings… → Apple Accounts，点 `+` 登录。
3. 左侧选中项目 `CholesterolMonitor` → TARGETS 选 `CholesterolMonitor` → Signing & Capabilities，保持勾选 “Automatically manage signing”，在 Team 里选你的团队（免费账号显示为 “你的名字 (Personal Team)”）。
4. 如果提示 Bundle Identifier 不可用，把 `io.github.pandaxgc.CholesterolMonitor` 改成你自己的唯一值，例如 `com.你的名字.CholesterolMonitor`。
5. 用数据线连接 iPhone，在 iPhone 上点“信任此电脑”。首次连接需在 iPhone 的 设置 → 隐私与安全性 → 开发者模式 中打开开发者模式并重启。
6. 在 Xcode 顶部的运行目标里选你的 iPhone，按 ⌘R 运行。
7. 免费账号首次安装后，iPhone 上会提示“不受信任的开发者”：打开 设置 → 通用 → VPN 与设备管理，信任你的开发者证书，再回到桌面打开 App。

免费账号签名的 App 7 天后需要重新用 Xcode 运行一次。数据只存在这台设备上；想先看效果，在 App 的 设置 → 数据 → 载入示例数据。

## 在模拟器上运行与测试

```sh
open CholesterolMonitor.xcodeproj            # 选 iPhone 17 Pro 模拟器，⌘R
swift test --package-path Packages/LipidDomain   # 领域测试
xcodebuild test -project CholesterolMonitor.xcodeproj -scheme CholesterolMonitor \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'   # 界面测试
```
