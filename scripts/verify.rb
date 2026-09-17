#!/usr/bin/env ruby
# ruby scripts/verify.rb [--online]
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
%w[rules rule-providers].each do |key|
  check(configs[0].fetch(key) == configs[1].fetch(key), "两端 #{key} 不一致")
end
check(File.read(File.join(ROOT, FILES[0])).match?(/^rules: #!replace$/), 'Stash rules 缺少 replace')
check(File.read(File.join(ROOT, FILES[0])).match?(/^proxy-groups: #!replace$/), 'Stash groups 缺少 replace')

configs.each do |config|
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
ai_hosts = %w[index-investing-daily-lcy.chaselee9999.chatgpt.site chatgpt.com api.openai.com
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
%w[notchatgpt.site chatgpt.site.example.com stripe.com sentry.io example.auth0.com
   apis.google.com maps.googleapis.com www.bing.com github.com].each do |host|
  check(!rules.any? { |r| r.split(',')[2] == AI && domain_match?(r, host) }, "无关域名被归入 AI #{host}")
end
puts "PASS: 两端 YAML、规则引用、节点筛选及 #{ai_hosts.size} 个 AI 域名"
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
  expected = ai_hosts.to_h { |host| [host, AI] }.merge(
    'github.com' => '🐙 GitHub', 'raw.githubusercontent.com' => '🐙 GitHub',
    'www.youtube.com' => '📹 YouTube', 'www.netflix.com' => '🎬 流媒体',
    'www.bilibili.com' => '🎯 全球直连', 'router.asus.com' => '🎯 全球直连')
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
    [['US01', 'JP01', 'SG01', 'HK01', 'Australia', '香港 Plus'], ['HK01'], []].each do |node_names|
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
