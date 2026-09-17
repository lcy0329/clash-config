# 优化进度

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
