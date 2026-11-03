#!/usr/bin/env ruby
# ruby scripts/verify.rb [--online] [--installed]
# Optional native checks: MIHOMO_BIN=/path/to/mihomo MIHOMO_MMDB=/path/to/Country.mmdb
require 'yaml'
require 'open3'
require 'tmpdir'
require 'fileutils'
require 'net/http'
require 'socket'
require 'json'
require 'timeout'

ROOT = File.expand_path('..', __dir__)
FILES = %w[stash/override.stoverride clash-verge/config.yaml].freeze
AI = '🤖 AI服务'

def check(condition, message)
  raise message unless condition
end

def domain_match?(rule, host)
  type, value = rule.split(',')
  case type
  when 'DOMAIN' then host == value
  when 'DOMAIN-SUFFIX' then host == value || host.end_with?(".#{value}")
  when 'DOMAIN-KEYWORD' then host.include?(value)
  else false # Domain-only checks; no DNS/IP/GeoIP simulation.
  end
end

configs = FILES.map { |file| YAML.load_file(File.join(ROOT, file)) }
['🚀 节点选择', '♻️ 自动选择'].each do |name|
  group = configs[1].fetch('proxy-groups').find { |g| g['name'] == name }
  excluded = Regexp.new(group.fetch('exclude-filter'))
  ['当前流量：12.52G / 150.00G', '到期时间：2027-01-31'].each do |node|
    check(excluded.match?(node), "桌面 #{name} 仍会选择订阅提示项 #{node}")
  end
  ['🇯🇵 日本 06', '🇭🇰 香港 10', 'US01', 'Singapore 01'].each do |node|
    check(!excluded.match?(node), "桌面 #{name} 误排除实际节点 #{node}")
  end
end
domestic_geoip = 'GEOIP,CN,DIRECT'
check(configs[0].fetch('rules') == configs[1].fetch('rules'), '两端公共规则必须一致')
check(configs[0]['rule-providers'] == configs[1]['rule-providers'], '两端规则源不一致')
check(File.read(File.join(ROOT, FILES[0])).match?(/^rules: #!replace$/), 'Stash rules 缺少 replace')
check(File.read(File.join(ROOT, FILES[0])).match?(/^proxy-groups: #!replace$/), 'Stash groups 缺少 replace')
check(File.read(File.join(ROOT, FILES[0])).match?(/^rule-providers: #!replace$/), 'Stash rule-providers 缺少 replace，会保留订阅旧规则集')

# Stash DNS must replace subscription arrays/policies, not prepend to them.
stash_text = File.read(File.join(ROOT, FILES[0]))
stash_dns = configs[0].fetch('dns')
check(configs[0]['ipv6'] == false && stash_dns['ipv6'] == false, 'Stash 必须同时关闭内核与应用 IPv6 解析')
check(stash_dns['follow-rule'] == false, 'Stash DNS 不应依赖代理组')
check(stash_dns['default-nameserver'] == %w[223.5.5.5 119.29.29.29], 'Stash DoH bootstrap 必须使用国内 IP')
check(stash_dns['nameserver'] == %w[https://dns.alidns.com/dns-query https://doh.pub/dns-query], 'Stash 仅使用两家国内 DoH')
check(stash_dns['proxy-server-nameserver'] == stash_dns['nameserver'], 'Stash 节点解析必须使用独立国内 DNS')
check(stash_dns['nameserver-policy'] == {'+.lan' => 'system', '+.local' => 'system', '+.home.arpa' => 'system'}, 'Stash 未清除旧 DNS policy 或丢失局域网解析')
check(stash_dns['fallback'] == [], 'Stash 不应保留订阅 fallback')
check(stash_text.match?(/^dns:\s*$/) && !stash_dns.key?('fake-ip-range'), 'Stash 应按键合并 DNS 并保留订阅 Fake-IP 网段')
check(stash_dns['fake-ip-filter'] == ['rule-set:china_domain'] && configs[0]['rule-providers'].key?('china_domain'), 'Stash 国内真实 IP 过滤必须引用现有规则源')
check(stash_text.match?(/^  fake-ip-filter: #!append$/), 'Stash Fake-IP 过滤必须追加，保留订阅过滤项')
%w[default-nameserver nameserver proxy-server-nameserver nameserver-policy fallback].each do |key|
  check(stash_text.match?(/^  #{Regexp.escape(key)}:.*#!replace\s*$/), "Stash #{key} 缺少 replace，旧 DNS 会继续生效")
end

domestic_hosts = %w[deepseek.com api.deepseek.com kimi.moonshot.cn www.kimi.com
  api.moonshot.ai doubao.com ime.doubao.com open.bigmodel.cn].to_h { |h| [h, 'DIRECT'] }.merge(
  %w[www.volcengine.com www.yuque.com gitee.com www.nowcoder.com xhslink.com
     video.bilicdn1.com www.wps.com daojia.com jiazheng.daojia.com
     jz-service-cdn.daojia.com].to_h { |h| [h, '🎯 全球直连'] })
configs.each do |config|
  domestic_hosts.each do |host, target|
    rule = config['rules'].find { |r| domain_match?(r, host) }
    check(rule && rule.split(',')[2] == target, "国内域名补漏失败 #{host}")
  end
  %w[notdeepseek.com deepseek.com.example.org notgitee.com gitee.com.example.org
     notdaojia.com daojia.com.example.org].each do |host|
    check(!config['rules'].any? { |r| domain_match?(r, host) }, "国内补漏误匹配相似域名 #{host}")
  end
  fallback = config['proxy-groups'].find { |g| g['name'] == '🐟 漏网之鱼' }
  check(fallback['proxies'].first == '🚀 节点选择', '未匹配请求默认须进入代理选择')
end

configs.each do |config|
  route_rules = config.fetch('rules')
  check(route_rules.count(domestic_geoip) == 1, '国内 GeoIP 必须允许解析并固定 DIRECT')
  geoip_index = route_rules.index(domestic_geoip)
  %w[github_rules microsoft apple telegram youtube netflix proxy_media gfw_list].each do |name|
    proxy_index = route_rules.index { |r| r.start_with?("RULE-SET,#{name},") }
    check(geoip_index < proxy_index, "国内 IP 判断必须先于通用代理规则 #{name}")
  end
  direct_group = config.fetch('proxy-groups').find { |g| g['name'] == '🎯 全球直连' }
  check(direct_group.fetch('proxies') == ['DIRECT'], '国内直连组不可再选代理节点')
  groups = config.fetch('proxy-groups')
  names = groups.map { |group| group.fetch('name') }
  check(names.uniq == names, '分组名称重复')
  targets = names + %w[DIRECT REJECT]
  groups.each do |group|
    group.fetch('proxies', []).each { |p| check(targets.include?(p), "未知分组引用 #{p}") }
  end
  config.fetch('rules').each do |rule|
    type, value, target = rule.split(',')
    target = value if type == 'MATCH'
    check(targets.include?(target), "未知规则目标 #{rule}")
    check(config['rule-providers'].key?(value), "未知规则集 #{value}") if type == 'RULE-SET'
    if target == AI
      check(%w[DOMAIN DOMAIN-SUFFIX].include?(type), "AI 规则范围过宽 #{rule}")
    end
  end
  check(config['rules'].last == 'MATCH,🐟 漏网之鱼', '兜底规则错误')
  ai = groups.find { |g| g['name'] == AI }
  check(ai['type'] == 'select' && ai['proxies'] == ['REJECT'], 'AI 必须手选固定节点并保留 REJECT')
  filter = Regexp.new(ai.fetch('filter'))
  ['US01', '🇺🇸 美国 01', 'United States 01', 'Japan 01', 'JP-02', 'SG 01', 'TW01', '新加坡 01', 'REJECT'].each do |name|
    check(filter.match?(name), "AI 漏选节点 #{name}")
  end
  ['United Kingdom 01', 'Australia 01', 'Russia 01', '香港 Plus 01', 'HK 01', 'DIRECT', 'JUST 01', 'Loser 01'].each do |name|
    check(!filter.match?(name), "AI 误选节点 #{name}")
  end
  {'🇭🇰 香港自动' => ['HK01', 'THK01'], '🇯🇵 日本自动' => ['JP01', 'JPLUS'],
   '🇺🇸 美国自动' => ['US01', 'Australia'], '🇸🇬 新加坡自动' => ['SG01', 'ASGARD']}.each do |name, (positive, negative)|
    regex = Regexp.new(groups.find { |g| g['name'] == name }.fetch('filter'))
    check(regex.match?(positive) && !regex.match?(negative), "地区筛选错误 #{name}")
  end
end

rules = configs[0].fetch('rules')
ai_hosts = %w[index-investing-daily-lcy.chaselee9999.chatgpt.site git.chatgpt-team.site chatgpt.com api.openai.com
  auth.openai.com cdn.oaistatic.com files.oaiusercontent.com chatgpt.livekit.cloud sora.com
  claude.ai api.anthropic.com claudeusercontent.com perplexity.ai
  gemini.google.com aistudio.google.com notebooklm.google.com notebooklm.google generativelanguage.googleapis.com
  copilot.microsoft.com copilot.cloud.microsoft api.githubcopilot.com copilot-proxy.githubusercontent.com
  origin-tracker.githubusercontent.com default.exp-tas.com
  cursor.com api2.cursor.sh marketplace.cursorapi.com cursor-cdn.com a.b.cursorvm.com
  api.x.ai grok.com openrouter.ai]
ai_hosts.each do |host|
  rule = rules.find { |r| domain_match?(r, host) }
  check(rule && rule.split(',')[2] == AI, "AI 域名漏分流 #{host}")
end
%w[notchatgpt.site chatgpt.site.example.com notchatgpt-team.site chatgpt-team.site.example.com stripe.com sentry.io example.auth0.com
   apis.google.com maps.googleapis.com www.bing.com github.com].each do |host|
  check(!rules.any? { |r| r.split(',')[2] == AI && domain_match?(r, host) }, "无关域名被归入 AI #{host}")
end
puts "PASS: 两端 YAML、规则引用、节点筛选及 #{ai_hosts.size} 个 AI 域名；Stash DNS/IPv6"
if ARGV.include?('--installed')
  desktop = configs[1]
  client = File.expand_path('~/Library/Application Support/io.github.clash-verge-rev.clash-verge-rev')
  merge_path = File.join(client, 'profiles/Merge.yaml')
  source_path = File.join(ROOT, 'clash-verge/config.yaml')
  check(File.symlink?(merge_path) && File.realpath(merge_path) == File.realpath(source_path), 'Clash 全局 Merge 必须链接到本仓库，不能独立维护副本')
  script_path = File.join(client, 'profiles/Script.js')
  check(File.symlink?(script_path) && File.realpath(script_path) == File.realpath(File.join(ROOT, 'clash-verge/script.js')), 'Clash 全局 Script 必须链接到本仓库')
  generated = YAML.load_file(File.join(client, 'clash-verge.yaml'))
  check(desktop.all? { |key, value| generated[key] == value }, 'Clash 生成配置与仓库不一致，请在订阅页重新激活订阅')
  dns_check = "const fs=require('fs'),vm=require('vm'),c={};vm.runInNewContext(fs.readFileSync(process.argv[1],'utf8'),c);process.stdout.write(JSON.stringify(c.main(JSON.parse(fs.readFileSync(0,'utf8'))).dns));"
  expected_dns, error, status = Open3.capture3('node', '-e', dns_check, script_path, stdin_data: JSON.generate(generated))
  check(status.success?, "全局 DNS 脚本执行失败: #{error.strip}")
  check(JSON.parse(expected_dns) == generated['dns'], 'Clash 生成 DNS 与全局脚本不一致，请重新激活订阅')
  controller = URI("http://#{generated.fetch('external-controller')}")
  http = Net::HTTP.new('127.0.0.1', controller.port, nil)
  http.open_timeout = http.read_timeout = 3
  request = Net::HTTP::Get.new('/rules')
  request['Authorization'] = "Bearer #{generated.fetch('secret')}"
  response = http.request(request)
  check(response.code == '200', '无法读取本机 Clash 运行规则')
  actual = JSON.parse(response.body).fetch('rules').map { |rule| [rule['type'].downcase, rule['payload'], rule['proxy']] }
  expected = desktop.fetch('rules').map do |rule|
    type, value, target = rule.split(',')
    value = value.downcase if type == 'GEOIP'
    type == 'MATCH' ? ['match', '', value] : [type.delete('-').downcase, value, target]
  end
  check(actual == expected, 'Clash 内核运行规则与仓库不一致，请在订阅页重新激活订阅')
  puts 'PASS: 全局 Merge/Script 链接、生成规则/DNS 及内核运行规则与仓库一致'
end
exit unless ARGV.include?('--online')

Dir.mktmpdir('clash-verify-') do |dir|
  providers = configs[1].fetch('rule-providers')
  # Downloads are isolated: no live application cache or subscription is touched.
  jobs = providers.map do |name, provider|
    Thread.new do
      body, error, status = Open3.capture3('curl', '-fsSL', '--connect-timeout', '10', '--max-time', '40', provider.fetch('url'))
      check(status.success?, "#{name} 下载失败: #{error.strip}")
      payload = provider['format'] == 'yaml' ? YAML.safe_load(body).fetch('payload') : body.lines.map(&:strip).reject { |s| s.empty? || s.start_with?('#') }
      check(payload.is_a?(Array) && !payload.empty?, "#{name} 为空或格式错误")
      check(payload.all? { |s| s.match?(/\A(?:DOMAIN|DOMAIN-SUFFIX|DOMAIN-KEYWORD|IP-CIDR|IP-CIDR6|IP-ASN),\S+/) }, "#{name} 含未知规则类型")
      path = File.join(dir, provider.fetch('path'))
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, body)
      [name, payload]
    end
  end
  payloads = jobs.map(&:value).to_h
  real_ip_hosts = %w[acs.m.taobao.com m5.amap.com cgi.connect.qq.com
    gnss-eph.oss-cn-hangzhou.aliyuncs.com v5-bd-daily-music.douyinstatic.com]
  domestic_filter = payloads.fetch('china_domain')
  real_ip_hosts.each do |host|
    check(domestic_filter.any? { |r| domain_match?(r, host) }, "Stash 国内真实 IP 过滤未覆盖 #{host}")
  end
  ai_hosts.each do |host|
    check(domestic_filter.none? { |r| domain_match?(r, host) }, "Stash 国内真实 IP 过滤误覆盖 AI #{host}")
  end
  puts "PASS: Stash 真实 IP 过滤覆盖 #{real_ip_hosts.size} 个国内样例，未覆盖 #{ai_hosts.size} 个 AI 样例"
  expected = ai_hosts.to_h { |host| [host, AI] }.merge(
    'github.com' => '🐙 GitHub', 'raw.githubusercontent.com' => '🐙 GitHub',
    'www.youtube.com' => '📹 YouTube', 'www.netflix.com' => '🎬 流媒体',
    'www.bilibili.com' => '🎯 全球直连', 'router.asus.com' => '🎯 全球直连',
    'acs.m.taobao.com' => '🎯 全球直连', 'gw.alipayobjects.com' => '🎯 全球直连',
    'wx.qlogo.cn' => '🎯 全球直连', 'v5-bd-daily-music.douyinstatic.com' => '🎯 全球直连',
    'maplocatesdksnapshot.d.meituan.net' => '🎯 全球直连', 'owner-api.vn.cloud.tesla.cn' => '🎯 全球直连',
    'th.pinduoduo.com' => '🎯 全球直连').merge(domestic_hosts)
  expected.each do |host, target|
    matched = rules.find do |rule|
      type, value = rule.split(',')
      type == 'MATCH' || (type == 'RULE-SET' ? payloads.fetch(value).any? { |r| domain_match?(r, host) } : domain_match?(rule, host))
    end
    parts = matched.split(',')
    actual = parts[0] == 'MATCH' ? parts[1] : parts[2]
    check(actual == target, "#{host}: 期望 #{target}，实际 #{actual} (#{matched})")
  end
  puts "PASS: #{providers.size} 个远程源下载及内容校验；#{expected.size} 个完整域名分流用例（不模拟 IP/GeoIP）"

  if ENV['MIHOMO_BIN']
    FileUtils.cp(ENV.fetch('MIHOMO_MMDB'), File.join(dir, 'Country.mmdb'))
    config = Marshal.load(Marshal.dump(configs[1]))
    # Real engine loads the original rules, providers and groups, with synthetic proxies.
    config['profile'] = {'store-selected' => false}
    config['log-level'] = 'warning'
    config['proxy-groups'].each { |g| g['interval'] = 0 }
    config['proxy-groups'].select { |g| g['type'] == 'url-test' }.each { |g| g['url'] = 'http://127.0.0.1:9/' }
    [['US01', 'JP01', 'SG01', 'HK01', 'Australia', '香港 Plus', '当前流量：15G / 150G', '到期时间：2027-01-31'], ['HK01'], []].each do |node_names|
      config['proxies'] = node_names.map { |name| {'name' => name, 'type' => 'http', 'server' => '127.0.0.1', 'port' => 9} }
      socket = TCPServer.new('127.0.0.1', 0)
      port = socket.addr[1]
      socket.close
      config['external-controller'] = "127.0.0.1:#{port}"
      path = File.join(dir, 'config.yaml')
      File.write(path, YAML.dump(config))
      output, status = Open3.capture2e(ENV['MIHOMO_BIN'], '-t', '-d', dir, '-f', path)
      check(status.success?, "Mihomo 配置校验失败: #{output}")
      pid = Process.spawn(ENV['MIHOMO_BIN'], '-d', dir, '-f', path, out: File.join(dir, 'core.log'), err: [:child, :out])
      begin
        http = Net::HTTP.new('127.0.0.1', port, nil)
        http.read_timeout = 2
        proxies = Timeout.timeout(15) do
          loop do
            begin
              break JSON.parse(http.get('/proxies').body).fetch('proxies')
            rescue Errno::ECONNREFUSED
              sleep 0.1
            end
          end
        end
        ai = proxies.fetch(AI)
        ['🚀 节点选择', '♻️ 自动选择'].each do |name|
          check(proxies.fetch(name).fetch('all').none? { |node| node.match?(/当前流量|到期时间/) }, "Mihomo #{name} 未排除订阅提示项")
        end
        check(ai['now'] == 'REJECT', 'Mihomo AI 默认选择未保护')
        wanted = ['REJECT'] + node_names.select { |name| %w[US01 JP01 SG01].include?(name) }
        check(ai.fetch('all').sort == wanted.sort, "Mihomo AI 成员不符: #{ai['all']}")
        loaded = JSON.parse(http.get('/providers/rules').body).fetch('providers')
        payloads.each do |name, entries|
          check(loaded.fetch(name).fetch('ruleCount') == entries.size, "Mihomo #{name} 规则未完整加载")
        end
      ensure
        Process.kill('TERM', pid)
        Process.wait(pid)
      end
    end
    puts 'PASS: Mihomo 原生配置加载与 AI 组正常/无匹配/无节点三种场景；默认 REJECT'
  end
end
