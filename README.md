# clash-config

自用代理配置，一套分流逻辑覆盖两个客户端：

| 客户端 | 文件 | 用途 |
|--------|------|------|
| **Clash Verge Rev**（桌面） | [`clash-verge/config.yaml`](clash-verge/config.yaml) | 全局 Merge 配置 |
| **Stash**（iOS） | [`stash/override.stoverride`](stash/override.stoverride) | 覆写（Override） |

两份配置的 **rules 与 rule-providers 保持一致**，代理组按客户端语法适配。订阅链接（含密钥）只留在各客户端本地，不进本仓库。

## 分组一览

- 🚀 节点选择（总开关） / ♻️ 自动选择（全局测速）
- 地区自动组：🇭🇰 香港 / 🇯🇵 日本 / 🇺🇸 美国 / 🇸🇬 新加坡（按节点名正则自动归类 + url-test 择优）
- 🤖 AI服务（ChatGPT / Sora / Claude / Gemini / AI Studio / NotebookLM / Microsoft 与 GitHub Copilot / Perplexity / Grok / Cursor / OpenRouter，手动选择固定节点）
- 🐙 GitHub / 📹 YouTube / 🎬 流媒体 / 📲 Telegram
- Ⓜ️ 微软 / 🍎 苹果（默认直连）
- 🛑 广告拦截 / 🎯 全球直连 / 🐟 漏网之鱼（兜底）

GitHub 规则来自 [blackmatrix7](https://github.com/blackmatrix7/ios_rule_script)，基础分流来自 [ACL4SSR](https://github.com/ACL4SSR/ACL4SSR)。ACL4SSR 使用 GitHub Raw 地址，规避本次检查遇到的 jsDelivr 地区限制；15 个远程规则集每 24 小时尝试更新。流媒体使用上游 `Clash/Providers/ProxyMedia.yaml`，避免原 `.list` 中的 `URL-REGEX` 在 Mihomo 中不兼容。

AI 域名直接维护在两份配置中，不再引入将整段 ASN、`stripe.com`、`sentry.io` 等通用域名归入 AI 的旧规则集。`chatgpt.site` 及所有子域名（含 `index-investing-daily-lcy.chaselee9999.chatgpt.site`）均走 `🤖 AI服务`。新增服务域名时需同步两端并更新覆写。

匹配顺序：局域网 → 明确 AI 域名 → 广告 → GitHub/微软/苹果/Telegram/影音 → 国内直连 → 兜底。AI 域名优先于通用 GitHub、流媒体与广告规则；非 AI 的第三方登录、支付、统计域名仍按后续规则处理。GitHub 的网页登录和 `api.github.com` 仍走 GitHub 组，不按 URL 路径区分 Copilot 登录接口。

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
3. 将该覆写挂到订阅上，在规则模式下使用。
4. 在 `🤖 AI服务` 中手动选择一个可用节点。配置显式加入了 `REJECT` 保护项，首次加载不要停留在 `REJECT`；已有选择可能由客户端保留。
5. **换机场时只换订阅、覆写不动**，但需重新确认 AI 节点和远程规则集更新状态。

仓库配置更新发布后，已有用户需在 Stash 中手动更新远程覆写并重新应用配置；若使用 jsDelivr 链接仍读到旧内容，可改用上面的 raw 链接。确认处于规则模式，在 `🤖 AI服务` 中选好可用节点，再重新连接并访问站点，在请求记录中检查是否命中 `DOMAIN-SUFFIX,chatgpt.site` 和 `🤖 AI服务`。下方 `interval: 86400` 只控制远程规则集更新，不会自动把仓库新增的内联规则带入手机。

### Clash Verge Rev（桌面）

把 [`clash-verge/config.yaml`](clash-verge/config.yaml) 内容粘到 **设置 → Merge / 全局扩展配置**，或在订阅的 Merge 字段引用本文件。

## 注意事项

- **地区组为空？** 先检查订阅是否正常，以及节点命名是否包含对应地区名称、国旗或 `US01` / `JP-01` 等缩写。缩写按英文字母边界匹配，避免把 Australia、Russia、香港 Plus 误归为美国。节点名称只用于筛选，不证明实际出口地区。
- **AI 节点策略**：仅列出美/日/新/台候选节点与 `REJECT`，不再引用自动测速或总开关组。选定一个实际可用节点；固定选择有助于保持出口稳定，但不能保证服务可用或账号状态。
- **空组保护**：Mihomo 设置 `empty-fallback: REJECT`，并实测无匹配/无订阅节点时保留 `REJECT`。Stash 使用显式 `proxies: [REJECT]`，正则也保留该项；不同版本的 `include-all` 合并行为需要在手机验证，不能将桌面结果等同于 Stash 实测。若候选为空且未显示 `REJECT`，先停用该配置，修正订阅或客户端配置，避免 Stash 将空组视为直连。
- **Stash 测速字段**：地区组的 `url`/`tolerance` 字段若在某些 Stash 版本不生效（不测速、不自动择优），删掉这两行、仅留 `interval` 与 `lazy` 即可（测速 URL 改由 App 全局设置控制）。
- **规则更新**：`interval: 86400` 是下载尝试周期；查看客户端的更新时间和错误日志确认成功。首次加载 GitHub Raw 失败时，先用已有可用代理连接更新；有缓存不代表更新正常。内联 AI 规则需要更新仓库配置。
- **游戏分流**：删除原先没有规则引用的游戏组；游戏请求仍按原有通用规则处理。

## 验证

只需系统 Ruby 和 curl，不需要安装依赖：

```sh
ruby scripts/verify.rb          # YAML、引用、两端一致性、正则正反例、AI 域名
ruby scripts/verify.rb --online # 另检查所有远程源及完整域名规则顺序
```

可选原生检查，在临时目录使用合成节点和 GeoIP 数据副本，不修改正在运行的客户端配置：

```sh
MIHOMO_BIN=/path/to/mihomo MIHOMO_MMDB=/path/to/Country.mmdb \
  ruby scripts/verify.rb --online
```

原生检查覆盖规则集加载数量及 AI 组的正常候选、无匹配、无节点三种场景。域名测试不模拟 IP/GeoIP；本机没有 Stash/iPhone 运行环境，手机验收仍需：更新覆写 → 确认 15 个规则集更新成功 → 确认 AI 组有 `REJECT` 和实际节点 → 选节点 → 重连 → 在请求记录确认目标站点命中 AI，并检查实际出口。此验证不代表节点连通性、账号登录或所有服务功能已实测。

维护域名时参考 [Cursor 官方网络清单](https://prod.cursor.com/docs/enterprise/network-configuration)、[GitHub Copilot 官方清单](https://docs.github.com/en/copilot/reference/copilot-allowlist-reference)；客户端语法参考 [Stash 策略组](https://stash.wiki/proxy-protocols/proxy-groups)与 [Mihomo 代理组](https://wiki.metacubex.one/config/proxy-groups/)。本轮方案与验证记录见 [task_plan.md](task_plan.md)、[findings.md](findings.md)、[progress.md](progress.md)。
