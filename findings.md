# 优化依据

## 2026-10-21 手机日志初检
- 输入为用户提供的 `2026-10-20-203740.log`，只作诊断数据；原始日志不复制进仓库。
- 共388行：344条连接失败，其中285条DNS解析失败（284条couldn't find ip、1条三台DNS均失败且首错SERVFAIL），49条IPv6无路由，9条127.0.0.1:80连接拒绝，1条其他传输错误；另有9次内存告警、32条网络变化通知。
- 失败连接全部走DIRECT：全球直连268、兜底52、苹果24。淘宝/支付宝、微信、抖音、美团、特斯拉等已命中国内直连，未见国内请求误走代理的证据。仅记录失败，不能推算所有请求失败率。
- 23:15切蜂窝后淘宝等集中DNS失败；06:02、18:24、19:53附近IPv6无路由与网络切换接近。内存可用约9.8–10MB，但没有OS终止隧道的记录，不能将内存视为已确认断线原因。
- 现有Stash覆写没有dns/ipv6字段，依赖订阅或其他覆写；日志未展示真实DNS地址，不能断言具体上游被封/被污染。
- 官方资料：[DNS](https://stash.wiki/features/dns-server)说明Fake-IP代理请求通常不需本地解析、DNS默认直连；顶层ipv6:false同时约束内核和应用AAAA（iOS3.6+）。[高效配置](https://stash.wiki/faq/effective-stash)建议手机1–2个国内DNS，UDP资源开销较低；大量classical规则增加内存和顺序匹配成本。[覆写语法](https://stash.wiki/configuration/override)说明列表默认前插，必须#!replace才能排除旧DNS列表。
- 实施取向：只调整Stash的解析链和IPv6，保留Fake-IP过滤/既有分流；不凭内存告警贸然改造三端规则源。
- 手机rule-providers改为#!replace：现有字段是字典，按官方语法默认递归合并，会留下订阅规则集；显式替换只保留覆写引用的15个。可以避免旧集合留存，但没有手机运行数据，不能量化内存改善或声称已消除内存告警。
- 辅助对照（Mac，不能代表iPhone/蜂窝网络）：6个日志域名分别经AliDNS/DNSPod的UDP及DoH查询。淘宝、微信、抖音、特斯拉可返回A记录；`th.pinduoduo.com`的UDP出现超时/SERVFAIL，而两家DoH均返回有效答案，因而最终选择双DoH，UDP仅作DoH域名bootstrap。独立curl包含DNS/TLS建连约0.7–1.5秒，UDP约1–233ms，不能当作Stash复用连接后的持续延迟或手机测速。
- `maplocatesdksnapshot.d.meituan.net`（日志38次）在两家UDP和DoH均为rcode=3/NXDOMAIN；部分日志错误来自不存在的目标域名，不能把285次全部归为上游故障。另1条传输错误是国内IP端口主动拒绝连接。
- IP形式DoH经TLS校验可用，但DNSPod官方[公告](https://docs.dnspod.cn/notices/mian-fei-ban-dot-dohbu-zai-gong-kai-ipjie-ru-de-gong-gao/)建议迁移到域名入口，最终使用`https://doh.pub/dns-query`及`https://dns.alidns.com/dns-query`，不采用DNSPod旧IP端点。

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
