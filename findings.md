# 优化依据

## 2026-11-02 国内 IP 自动判断
- 用户要求按IP国家通用识别国内请求。现有手机`GEOIP,CN`带no-resolve，且三端国内域名/IP段排在GitHub/微软/影音/GFW等规则之后；已匹配的代理规则不会再进入末尾国内判断。
- [Stash规则类型](https://stash.wiki/rules/rule-types)明确GEOIP匹配MaxMind国家代码，no-resolve会避免触发DNS；[DNS说明](https://stash.wiki/features/dns-server)说明Fake-IP需要按路由规则决定是否真实解析。此前保留no-resolve是DNS异常期间的分步选择，现在按用户要求结束该限制。
- 实施范围：国内域名、公司IP和GeoIP前移到通用代理规则之前；国内GeoIP允许真实解析并使用固定DIRECT；全球直连组只保留DIRECT，避免旧手选节点再次改变国内分流。明确AI、广告及路由设备专属出口保留优先级。
- 边界：国家判断依赖DNS可用性及GeoIP数据，不能承诺数据库无误差、所有国内App都只使用国内IP，或替代家庭路由独立的代理规则；没有确认此前App故障的唯一根因。
- 隔离兼容内核实测：使用已安装Mihomo、MMDB副本、全部15源的文件副本、仅回环监听的可控DNS与合成节点。旧手机规则下，未收录国内域名/Fake-IP请求命中MATCH、通用GFW域名即使指定国内A记录也先命中代理，未发起真实A查询。新规则下三者均触发本地A查询并命中GeoIP(CN)/DIRECT。
- 新规则9项原生路由决策通过：未知国内/境外域名、通用GFW域名分别解析国内/境外IP、明确AI、国内/境外裸IP、广告域名、Fake-IP还原后国内判断。AI保持原优先级（测试为REJECT保护项），广告保持REJECT；只验证决策，不把测试端口连接成功或Mihomo当作iPhone网络验收。核心与DNS均已退出，线上客户端未热加载。
- 临时验证脚本曾遇到样例源没有精确DOMAIN、JSON代理组Unicode转义、规则源需原生payload行以及日志格式差异；修正后等待15源数量全部正确再测试，先前未完整加载规则源的结果全部作废。

## 2026-11-02 天鹅到家打不开
- 用户反馈11月1日手机开启Stash时天鹅到家打不开，关闭Stash后能打开，说明需优先检查Stash路径，但不能仅据此区分路由、DNS、拦截或客户端检测。
- 官方当前[用户协议](https://hd.daojia.com/agreements/user/)及[官网](https://www.daojia.com/)使用`daojia.com`，官网资源和现行协议分别位于`static.daojia.com`等子域；主域归属有官方依据，不依据第三方广义58列表放行。
- 已搜索现有11月目录的手机日志，未发现daojia/58dj/58cdn等可识别域名；已有WARN级日志不能据缺少请求断言App没发起连接或使用了哪条规则。
- 全部15源完成下载核对，`daojia.com`及官网/API/协议/CDN子域没有任何域名规则命中；纯域名顺序检查落入MATCH。手机国内GEOIP保留no-resolve，缺少可供判断的真实IP时存在代理兜底风险；不是对昨日手机实际请求链路的抓包证明。
- 最小修正：在共享国内服务补充段加入一条`DOMAIN-SUFFIX,daojia.com,🎯 全球直连`，位于广告之后、通用代理之前；不放行整个58系、不变更DNS/Fake-IP/IPv6。手机需规则模式、全球直连组选DIRECT，成功与否待App复测。
- 取源过程：直连google_cn超过25秒无响应；使用已有本机7897代理后15源全部取到。临时检查脚本首次使用系统Ruby不支持的filter_map，改为map.compact后完成。下载检查不是手机连通实测，也没有改动本机系统代理。
- 发布内容隔离校验通过：15个规则源、62个完整域名顺序用例（含3个天鹅到家样例）、5个国内真实IP过滤样例与31个AI排除样例；相似域名反例通过。未使用Mihomo或电脑网页访问作为手机App修复验证。

## 2026-11-01 三份手机日志复查
- 输入为`2026-10-31-005246.log`（176行）、`2026-10-31-183858.log`（89行）与`2026-10-31-231452.log`（560行，跨11月1日）。原始日志未复制进仓库。
- 三份分别出现20/16/466条`udp relay failed: unmapped fake IP`，合计502条；这是UDP转发无法找到虚拟IP映射的实际失败，不是广告拦截。记录条数不能当作独立用户请求数或失败率。
- 23:14文件加载3499条映射后仍对198.18.22.202报错448次，另对198.18.0.1报错18次；主要集中在10月31日23:14–23:56，下一次网络变化在11月1日02:51。不能将这一长段简单解释为当次Wi-Fi/蜂窝切换。
- 另两份启动时加载3136/3416条映射；缺少映射的原因仍可能涉及缓存、应用旧DNS、其他DNS来源或客户端处理。日志无原域名，不能据此定位具体App，也不能宣称已经确认某个Stash版本缺陷。
- 18:48:44–45还有13条真实A解析超时，涉及高德、淘宝、优酷、微信及阿里云；这些请求已经DIRECT。三份共有17条DoH HTTP/2连接告警；与名称不存在的负应答分开处理。
- 三份没有REJECT或内存告警。无效上游fc-.cdn.bcebos.com条目被单独跳过，内核正常启动；不将其等同全局配置载入失败。
- 日志中家庭网段与此前OpenClash一致，存在与其他DNS来源/Fake-IP网段相互作用的可能，但尚未取得对应域名和路由映射，不能断言网段冲突，也不改动路由。
- 官方[DNS说明](https://stash.wiki/features/dns-server)允许fake-ip-filter引用现有rule-set并返回真实IP。本轮覆写只追加rule-set:china_domain，减少已知国内请求的映射依赖，保留订阅过滤项、其余流量和现有网段。ChinaDomain当前635条，其中626条域名规则，9条IP规则不参与域名匹配；现有31个AI测试域名均未命中该集合。
- 官方[App Store](https://apps.apple.com/hk/app/stash/id1596063349)和iTunes HK查询在本次复查返回3.6.5；未发现能据以承诺修复该问题的新版本说明，不随意建议降级或切TestFlight。
- 兼容性调整不是已验证的根因修复；不会消除目标域名自身的NXDOMAIN，也不保证解决独立的DoH超时。发布后需手机重新应用，并重启手机/受影响App以排除旧DNS缓存。

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
