# 优化进度

## 2026-10-21 Stash 国内 App 卡顿排查
- 发布前对提交内容单独验证：首次GitHub Raw的LocalAreaNetwork下载40秒超时，HTTP/1.1单独复查200，随后完整重测15/15规则源和44个分流用例通过；不包含工作区原有路由校验与额外YouTube用例。
- 已读取手机日志并统计DNS/IPv6/内存异常；确认失败请求本来已经直连。
- 已核对Stash官方DNS/覆写文档和现有验证脚本。工作区原有路由与文档修改保留，未读取订阅密钥或复制原始日志。
- 已完成Mac上的两家DNS UDP/DoH辅助对照（不是手机线路实测）：发现拼多多UDP失败、DoH成功，以及美团一个域名多端点一致NXDOMAIN；不将全部解析失败都归为DNS服务故障。
- 已修改手机DNS为两家国内DoH、明确替换旧上游/策略/fallback、关闭DNS跟随代理与IPv6；保留Fake-IP过滤及原分流。补充验证脚本中的DNS合并约束和7个日志域名直连用例，以及导入/版本/切网验收说明。
- 手机rule-providers加#!replace，避免订阅旧规则集残留；业务规则与15个规则源内容不变，未改桌面/路由配置。
- 修改后离线验证通过；在线15/15规则源下载解析成功，域名分流用例通过（新增7个手机日志国内域名）。未使用Mihomo测试代替Stash验证；仓库更新不等于应用到手机。手机实际生效、切网和内存改善需要在iPhone验收。

## 2026-09-17
- 开始时工作区干净，基于 main 的 chatgpt.site 修复继续优化。
- 已读取两端完整配置和 README，创建优化计划。
- 下一步：核对客户端策略组语义，确定最小可验证实现。

- 已替换 ACL4SSR 下载源、内联精确 AI 域名、收紧地区筛选、删除无引用游戏分组。
- 已新增 scripts/verify.rb；静态验证通过，正在运行远程资源和 Mihomo 隔离加载检查。
- 在线检查揭示旧 ProxyMedia.list 的 URL-REGEX 兼容性问题；改用同上游的 Clash/Providers/ProxyMedia.yaml（368 条规则）。
- 已补充 Copilot 配套端点、NotebookLM 和 Sora，避免落入流媒体组。

## 最终验证
- `ruby scripts/verify.rb`：通过，两端 YAML、引用、规则一致性、地区筛选正反例、31 个 AI 域名。
- `ruby scripts/verify.rb --online`（带 MIHOMO_BIN / MIHOMO_MMDB）：15 个源全部成功，37 个完整域名顺序用例通过；原生内核三种节点场景均通过，并检查每个规则集加载条数。
- 旧配置对照：新脚本按预期失败，能发现旧 AI 远程规则范围过宽的问题。
- `git diff --check`：通过。
- 所有原生测试使用临时目录、合成节点和 GeoIP 数据副本；未修改正在运行的客户端配置。
- 交付：更新 README，提供可重复验证命令和手机验收步骤；准备提交至当前 main 并同步 origin/main。
- 限制：没有在真实 iPhone/Stash 运行，不能证明 Stash include-all 与 REJECT 的实际合并结果，也没有验证真实节点/账号连通性。
