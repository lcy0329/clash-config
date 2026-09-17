# 优化依据

## 已有审计（2026-09-17）
- 两端 rules / rule-providers 相同。
- 14 个 ACL4SSR jsDelivr 地址在当前网络返回 403，响应提示地区限制；对应 GitHub Raw 地址均成功。
- AI 节点正则会误匹配 United Kingdom、Australia、Russia、香港 Plus。
- 域名匹配：cursor.com / aistudio.google.com 进入流媒体；cursorapi.com / cursor-cdn.com 进入兜底；GitHub Copilot API 进入 GitHub。
- OpenAI / Copilot 规则包含通用 SaaS 域名与 ASN 规则，扩大 AI 分流范围。
- 游戏组未被规则或其他组引用。

## 来源（仅作为事实参考）
- Stash 策略组与空组行为：https://stash.wiki/proxy-protocols/proxy-groups
- Stash 规则集：https://stash.wiki/rules/rule-set
- Cursor 网络域名：https://prod.cursor.com/docs/enterprise/network-configuration
- GitHub Copilot 域名：https://docs.github.com/en/copilot/reference/copilot-allowlist-reference

## 验证边界
- Stash include-all 与显式 proxies 的合并尚需手机确认；本轮加入 REJECT 并保留正则匹配，不宣称 iOS 运行时验证通过。
- 已按现有上游与官方清单保留专用验证/配套域名；通用 SaaS 不再整体归入 AI。真实登录与支付流程需设备验收。

## 本轮核对
- Stash 官方文档确认覆写数组默认前置、#!replace 完全替换；继续保留 rules/proxy-groups 的 replace。
- 本地已有 Clash Verge 的 verge-mihomo，可在临时目录用合成节点测试，不接触用户订阅密钥或现有运行配置。
- Stash 未安装在本机，不能声称已完成 iOS 内核实测；保留手机验收步骤。
- 仓库历史记录曾遇到 Stash include-all 与显式策略组混用的问题，空组保护需要避免依赖未验证的字段。

## 实施选择
- AI 域名内联于两端配置，删除 OpenAI/Gemini/Copilot 三个过宽的远程源；保留 GitHub 和基础分流源共 15 个。
- AI 明确服务域名置于广告规则之前，避免服务自身端点被通用广告规则先匹配。
- GitHub 官方清单还列出 origin-tracker.githubusercontent.com 和 default.exp-tas.com，纳入明确配套端点。
- Stash 不配置 Mihomo 专有 empty-fallback；使用显式 REJECT 并在 filter 中保留 REJECT。该组合仍需手机确认其 include-all 合并行为，不能把桌面测试作为 Stash 测试。
- ACL4SSR ProxyMedia.list 同时包含 AI、通用 SaaS、URL-REGEX 与 Android 进程名。优先选取不混入 AI 的流媒体专用源，避免只修下载而保留分类污染。
- 最终流媒体源选择同仓库 Clash/Providers/ProxyMedia.yaml：368 条 DOMAIN/DOMAIN-SUFFIX/DOMAIN-KEYWORD/IP-CIDR，无 URL-REGEX。仍含上游 AI 条目；本仓库明确 AI 域名规则优先处理已支持服务，未宣称上游内容全部纯净。
