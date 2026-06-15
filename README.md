# clash-config

自用代理配置，一套分流逻辑覆盖两个客户端：

| 客户端 | 文件 | 用途 |
|--------|------|------|
| **Clash Verge Rev**（桌面） | [`clash-verge/config.yaml`](clash-verge/config.yaml) | 全局 Merge 配置 |
| **Stash**（iOS） | [`stash/override.stoverride`](stash/override.stoverride) | 覆写（Override） |

两份配置**分流逻辑完全一致**，仅内核语法不同。订阅链接（含密钥）只留在各客户端本地，不进本仓库，可放心公开。

## 分组一览

- 🚀 节点选择（总开关） / ♻️ 自动选择（全局测速）
- 地区自动组：🇭🇰 香港 / 🇯🇵 日本 / 🇺🇸 美国 / 🇸🇬 新加坡（按节点名正则自动归类 + url-test 择优）
- 🤖 AI服务（ChatGPT / Claude / Gemini / Copilot / Perplexity / Grok / Cursor，默认走美国）
- 🐙 GitHub / 📹 YouTube / 🎬 流媒体 / 📲 Telegram
- Ⓜ️ 微软 / 🍎 苹果 / 🎮 游戏（默认直连）
- 🛑 广告拦截 / 🎯 全球直连 / 🐟 漏网之鱼（兜底）

规则集来自 [blackmatrix7](https://github.com/blackmatrix7/ios_rule_script)（AI/GitHub）与 [ACL4SSR](https://github.com/ACL4SSR/ACL4SSR)（基础分流），经 jsDelivr CDN 引用，每日自动更新。

## 使用方法

> 把下方链接里的 `<YOUR_GITHUB_USERNAME>` 替换成你的 GitHub 用户名。

### Stash（iPhone）

1. 照常在 Stash 里导入机场订阅。
2. **设置 → 覆写（Override）→ 添加 → 远程**，填入：
   ```
   https://raw.githubusercontent.com/<YOUR_GITHUB_USERNAME>/clash-config/main/stash/override.stoverride
   ```
   国内访问 `raw.githubusercontent.com` 不稳时，改用 jsDelivr：
   ```
   https://cdn.jsdelivr.net/gh/<YOUR_GITHUB_USERNAME>/clash-config@main/stash/override.stoverride
   ```
3. 将该覆写挂到订阅上 → 分组和规则生效。
4. **换机场时只换订阅、覆写不动**，分组规则自动复用。

### Clash Verge Rev（桌面）

把 [`clash-verge/config.yaml`](clash-verge/config.yaml) 内容粘到 **设置 → Merge / 全局扩展配置**，或在订阅的 Merge 字段引用本文件。

## 注意事项

- **地区组为空？** 说明机场节点命名不含对应关键词（如用国旗 emoji 或别名）。改各地区组的 `filter` 正则即可。
- **AI 节点策略**：ChatGPT/Claude 对 IP 要求严格（需非大陆、非被风控的机房 IP），美国不一定最优。🤖 AI服务 是 `select` 组，可在 App 内手动切换地区试用。
- **Stash 测速字段**：地区组的 `url`/`tolerance` 字段若在某些 Stash 版本不生效（不测速、不自动择优），删掉这两行、仅留 `interval` 与 `lazy` 即可（测速 URL 改由 App 全局设置控制）。
- **规则更新**：`interval: 86400` 表示 24h 拉取一次远程规则集，无需手动维护。
