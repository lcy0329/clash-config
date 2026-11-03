# clash-config

自用代理配置，一套分流逻辑覆盖两个客户端：

| 客户端 | 文件 | 用途 |
|--------|------|------|
| **Clash Verge Rev**（桌面） | [`clash-verge/config.yaml`](clash-verge/config.yaml) | 全局 Merge 配置 |
| **Stash**（iOS） | [`stash/override.stoverride`](stash/override.stoverride) | 覆写（Override） |

两份配置共享域名规则与 rule-providers，代理组按客户端语法适配。国内域名优先直连；未命中域名规则的请求允许解析真实IP，按GeoIP判断国内后固定直连，再进入通用代理规则。订阅链接（含密钥）只留在各客户端本地，不进本仓库。

## 分组一览

- 🚀 节点选择（总开关） / ♻️ 自动选择（全局测速）
- 地区自动组：🇭🇰 香港 / 🇯🇵 日本 / 🇺🇸 美国 / 🇸🇬 新加坡（按节点名正则自动归类 + url-test 择优）
- 🤖 AI服务（ChatGPT / Sora / Claude / Gemini / AI Studio / NotebookLM / Microsoft 与 GitHub Copilot / Perplexity / Grok / Cursor / OpenRouter，手动选择固定节点）
- 🐙 GitHub / 📹 YouTube / 🎬 流媒体 / 📲 Telegram
- Ⓜ️ 微软 / 🍎 苹果（默认直连）
- 🛑 广告拦截 / 🎯 全球直连 / 🐟 漏网之鱼（兜底）

GitHub 规则来自 [blackmatrix7](https://github.com/blackmatrix7/ios_rule_script)，基础分流来自 [ACL4SSR](https://github.com/ACL4SSR/ACL4SSR)。ACL4SSR 使用 GitHub Raw 地址，规避本次检查遇到的 jsDelivr 地区限制；15 个远程规则集每 24 小时尝试更新。流媒体使用上游 `Clash/Providers/ProxyMedia.yaml`，避免原 `.list` 中的 `URL-REGEX` 在 Mihomo 中不兼容。

AI 域名直接维护在两份配置中，不再引入将整段 ASN、`stripe.com`、`sentry.io` 等通用域名归入 AI 的旧规则集。`chatgpt.site` 及所有子域名（含 `index-investing-daily-lcy.chaselee9999.chatgpt.site`）、`chatgpt-team.site`（含 Git 工具入口）均走 `🤖 AI服务`。新增服务域名时需同步两端并更新覆写。

匹配顺序：局域网 → 明确国内 AI / 明确海外 AI → 广告 → 国内补充域名与国内域名/IP/国家判断 → GitHub/微软/苹果/Telegram/影音/GFW → 兜底。明确海外AI仍保留专用出口；通用代理规则必须排在国内IP判断之后。

2026-10-30 补齐 DeepSeek、豆包（含输入法）、Kimi/Moonshot、智谱、火山引擎、语雀、Gitee、牛客、小红书短链、B站 bilicdn1 与 WPS 域名。国内 AI 明确直连，其他补充服务在广告过滤之后、通用代理规则之前匹配。桌面最后的 `GEOIP,CN` 允许必要时先解析真实 IP；当时手机保留 `no-resolve`；2026-11-02已取消该限制并前移国内判断。

2026-11-02 国内IP统一判断：`GEOIP,CN,DIRECT`不带`no-resolve`，与国内域名/公司IP规则一起位于通用代理规则之前。未知域名无需逐个添加：解析结果被GeoIP识别为CN后直接出站，其余再按代理规则处理；`🎯 全球直连`仅保留DIRECT，避免手选代理覆盖国内直连。明确AI出口、广告和路由设备专属出口仍有优先级。未知域名可能多一次本地DNS查询，依赖解析服务与GeoIP数据有效；不保证每个国内App只使用国内IP，也不能代替家庭路由规则或手机实际验收。

2026-11-02 补齐天鹅到家官方域名 `daojia.com` 及其子域，进入 `🎯 全球直连`；应用后确认处于规则模式、该组选择 DIRECT。此前15个规则源没有覆盖该域名，手机缺少真实IP供国内规则判断时可能进入代理兜底。此次只补充分流，App能否恢复仍需手机更新覆写并重新打开后验证。

发布后在 Stash 更新原远程覆写并重新应用，配置描述应显示 2026-11-03 15:19:19；仅更新订阅或规则集不会更新这些内联规则。若使用 jsDelivr 尚未取得新版，可换用下方 GitHub Raw 链接。确认 `🎯 全球直连` 为 DIRECT；`🐟 漏网之鱼` 默认选节点选择，已有选择可能被保留。

## 使用方法

> 下方链接可以直接复制使用。

### Stash（iPhone）

1. 照常在 Stash 里导入机场订阅。
2. **设置 → 覆写（Override）→ 添加 → 远程**，填入：
   ```
   https://raw.githubusercontent.com/lcy0329/clash-config/main/stash/override.stoverride
   ```
   国内访问 `raw.githubusercontent.com` 不稳时，改用 jsDelivr：
   ```
   https://cdn.jsdelivr.net/gh/lcy0329/clash-config@main/stash/override.stoverride
   ```
3. 将该覆写挂到订阅上，在规则模式下使用。
4. 在 `🤖 AI服务` 中手动选择一个可用节点。配置显式加入了 `REJECT` 保护项，首次加载不要停留在 `REJECT`；已有选择可能由客户端保留。
5. **换机场时只换订阅、覆写不动**，但需重新确认 AI 节点和远程规则集更新状态。

仓库配置更新发布后，已有用户需在 Stash 中手动更新远程覆写并重新应用配置；若使用 jsDelivr 链接仍读到旧内容，可改用上面的 raw 链接。确认处于规则模式，在 `🤖 AI服务` 中选好可用节点，再重新连接并访问站点，在请求记录中检查是否命中 `DOMAIN-SUFFIX,chatgpt.site` 和 `🤖 AI服务`。下方 `interval: 86400` 只控制远程规则集更新，不会自动把仓库新增的内联规则带入手机。

手机覆写明确使用阿里/DNSPod 两家国内 DoH，DNS 查询直连；替换订阅的旧 DNS 列表、域名策略和 fallback，保留订阅的 Fake-IP 地址范围，`.lan` / `.local` / `.home.arpa` 使用系统 DNS。`fake-ip-filter` 追加引用现有 `china_domain`，让该集合中的域名返回真实 IP，减少国内应用对 Fake-IP 映射的依赖，订阅原有过滤项保留。其余未被过滤的域名继续使用 Fake-IP，业务分流规则不变。远程规则集完整替换为本文件使用的15个，避免订阅旧规则集留存。针对手机日志中的切网 IPv6 无路由，暂设顶层和 `dns.ipv6: false`；这些开关及规则集过滤需要 **iOS Stash 3.6+**。语法依据见 [Stash DNS 文档](https://stash.wiki/features/dns-server)。

2026-11-01 调整依据：三份手机日志合计502条 `udp relay failed: unmapped fake IP`，同时另有国内域名真实解析超时。国内真实IP解析是针对映射依赖的兼容性调整，尚不能证明映射缺失的具体原因或已解决全部卡顿。更新后先确认覆写描述里的时间，重新应用配置；建议重启手机一次，让应用重新获取DNS结果。保持 `🛑 广告拦截` 为 REJECT，随后正常使用并观察新日志。此改动不修复不存在的目标域名，也不能代替手机实测；若需撤回，只删除本轮 `fake-ip-filter` 追加段，再重新应用即可。

应用手机优化：先确认 Stash 版本，再用本地文件替换现有覆写，或在仓库发布后更新远程覆写；将它放在其他会修改 DNS/IPv6 的覆写之后，重新应用并断开/重连。Wi-Fi 和蜂窝网络各测试淘宝、微信、抖音，再切换网络复测，观察是否仍有大量 `couldn't find ip` / `no route to host`。本地修改不会自动更新手机；本机 DNS 对照和配置检查也不能替代手机实测。日志中部分域名经两家 DoH 均返回 NXDOMAIN，不能承诺所有 DNS 告警都消失。IPv6 网络修复后，可删除两个 `ipv6: false` 字段恢复自动判断。

### 手机日志与排查

主覆写明确设置 `log-level: info`，用于日常观察；实际导出内容和字段取决于Stash版本，需从更新后的手机日志确认。日志等级依据[官方配置样例](https://stash.wiki/configuration/example-config)。

需要更详细地复现卡顿时，在同一订阅下添加远程覆写 [`临时排障日志`](https://raw.githubusercontent.com/lcy0329/clash-config/main/stash/debug.stoverride)，将它放在主覆写之后并启用、重新应用；它只将日志级别改为debug。复现并采集前后约5–10分钟的日志后，关闭此覆写并重新应用，恢复主覆写的info；不建议长期打开debug。覆写按从上到下应用，见[官方说明](https://stash.wiki/configuration/override)。

发生问题时，保留当前核心日志，并尽快查看对应连接的详情，提供目标域名/IP、命中规则、代理链/节点、错误信息；同时记录当时Wi-Fi或蜂窝网络，运行Stash的网络诊断并保留结果。DNS检查中如有应答服务器、解析答案和耗时，也一并提供。短连接可能已消失，可先开启临时debug再重新打开有问题的App。没有警告不能证明网速或所有业务正常；日志里没有的字段以连接详情/诊断补充，不假定核心日志会自动包含全部信息。

本方案不需要开启HTTPS解密或外部控制，也不会自动上传日志。日志可能包含域名、IP与节点名，分享前检查并去掉订阅链接、API密钥等信息。

### Clash Verge Rev（桌面）

**桌面只维护本仓库的两份文件：[`clash-verge/config.yaml`](clash-verge/config.yaml) 管分流、[`clash-verge/script.js`](clash-verge/script.js) 管 DNS。** 本机的全局 `profiles/Merge.yaml` 和 `profiles/Script.js` 分别软链接到它们。订阅只提供节点及保留的 DNS 兼容字段，换订阅仍共享全局规则和 DNS 策略。

后续流程：编辑仓库文件或 `git pull` → Clash **订阅 → 重新激活订阅** → `ruby scripts/verify.rb --installed`。软链接更新文件内容，重新激活才会让内核应用改动；不要把编辑器中的客户端副本另存为独立文件。移动仓库后需重建链接。

其他 Mac 初次设置时，在仓库根目录执行以下命令，先备份现有 Merge/Script，再建立链接，然后重新激活订阅：

```sh
clash_dir="$HOME/Library/Application Support/io.github.clash-verge-rev.clash-verge-rev"
cp -p "$clash_dir/profiles/Merge.yaml" "$clash_dir/profiles/Merge.yaml.bak.$(date +%Y%m%d-%H%M%S)"
cp -p "$clash_dir/profiles/Script.js" "$clash_dir/profiles/Script.js.bak.$(date +%Y%m%d-%H%M%S)"
ln -sfn "$PWD/clash-verge/config.yaml" "$clash_dir/profiles/Merge.yaml"
ln -sfn "$PWD/clash-verge/script.js" "$clash_dir/profiles/Script.js"
```

桌面主组与全局自动组排除订阅中的“当前流量／到期时间”等提示项，避免将提示项当作自动选择候选。

全局 Script 在 Merge 之后运行：国内域名保留原来的国内解析；明确归入 `🤖 AI服务` 的 `DOMAIN` / `DOMAIN-SUFFIX` 规则自动生成 DNS 策略，经所选 AI 节点访问 Cloudflare/Google DoH。域名只维护在 Merge 中，DNS 不再复制名单；AI 组选 REJECT 或节点失效时，该类解析也会失败。脚本替换订阅的 DNS 上游和解析策略，同时保留传入的 DNS 模式、Fake-IP 范围及过滤等兼容字段。旧脚本会丢弃模式；本机修正后恢复为 Clash 传入的 `fake-ip`，普通 `dig` 会得到 `198.18.*` 映射，真实上游答案通过内核 `/dns/query` 核实。

2026-11-03 实测本机 DNS 对 `api.openai.com` 返回 `118.184.26.113`，而经代理查询 Cloudflare/Google 均返回 `162.159.140.245` / `172.66.0.243`。原来的 `fallback-filter.geoip-code: CN` 会接受中国地址，不能识别这类错误答案，因此对明确 AI 域名直接使用境外 DoH。此修改针对 DNS 解析；长会话请求过大导致的重连需另行处理。语法依据见 [Mihomo DNS 文档](https://wiki.metacubex.one/config/dns/)。

## 注意事项

- **地区组为空？** 先检查订阅是否正常，以及节点命名是否包含对应地区名称、国旗或 `US01` / `JP-01` 等缩写。缩写按英文字母边界匹配，避免把 Australia、Russia、香港 Plus 误归为美国。节点名称只用于筛选，不证明实际出口地区。
- **AI 节点策略**：仅列出美/日/新/台候选节点与 `REJECT`，不再引用自动测速或总开关组。选定一个实际可用节点；固定选择有助于保持出口稳定，但不能保证服务可用或账号状态。
- **空组保护**：Mihomo 设置 `empty-fallback: REJECT`，并实测无匹配/无订阅节点时保留 `REJECT`。Stash 使用显式 `proxies: [REJECT]`，正则也保留该项；不同版本的 `include-all` 合并行为需要在手机验证，不能将桌面结果等同于 Stash 实测。若候选为空且未显示 `REJECT`，先停用该配置，修正订阅或客户端配置，避免 Stash 将空组视为直连。
- **Stash 测速字段**：地区组的 `url`/`tolerance` 字段若在某些 Stash 版本不生效（不测速、不自动择优），删掉这两行、仅留 `interval` 与 `lazy` 即可（测速 URL 改由 App 全局设置控制）。
- **规则更新**：`interval: 86400` 是下载尝试周期；查看客户端的更新时间和错误日志确认成功。首次加载 GitHub Raw 失败时，先用已有可用代理连接更新；有缓存不代表更新正常。内联 AI 规则需要更新仓库配置。
- **游戏分流**：删除原先没有规则引用的游戏组；游戏请求仍按原有通用规则处理。

## 验证

基础校验使用系统 Ruby 和 curl；DNS 脚本及本机一致性校验另外需要 Node.js，不需要第三方包：

```sh
ruby scripts/verify.rb          # YAML、引用、两端一致性、AI 域名、Stash DNS/IPv6
ruby scripts/verify.rb --installed # 本机 Merge/Script 链接、生成规则/DNS 与运行规则；需 Node.js
node scripts/verify-dns.js      # 全局 DNS 脚本行为；需 Node.js，无第三方依赖
ruby scripts/verify.rb --online # 另检查所有远程源及完整域名规则顺序
```

可选原生检查，在临时目录使用合成节点和 GeoIP 数据副本，不修改正在运行的客户端配置：

```sh
MIHOMO_BIN=/path/to/mihomo MIHOMO_MMDB=/path/to/Country.mmdb \
  ruby scripts/verify.rb --online
```

原生检查覆盖规则集加载数量及 AI 组的正常候选、无匹配、无节点三种场景。域名测试不模拟 IP/GeoIP；本机没有 Stash/iPhone 运行环境，手机验收仍需：更新覆写 → 确认 15 个规则集更新成功 → 确认 AI 组有 `REJECT` 和实际节点 → 选节点 → 重连 → 在请求记录确认目标站点命中 AI，并检查实际出口。此验证不代表节点连通性、账号登录或所有服务功能已实测。

维护域名时参考 [Cursor 官方网络清单](https://prod.cursor.com/docs/enterprise/network-configuration)、[GitHub Copilot 官方清单](https://docs.github.com/en/copilot/reference/copilot-allowlist-reference)；客户端语法参考 [Stash 策略组](https://stash.wiki/proxy-protocols/proxy-groups)与 [Mihomo 代理组](https://wiki.metacubex.one/config/proxy-groups/)。本轮方案与验证记录见 [task_plan.md](task_plan.md)、[findings.md](findings.md)、[progress.md](progress.md)。
