// Clash Verge Rev 全局扩展脚本：在全局 Merge 之后统一 DNS。
// 唯一维护源是本文件；本机 profiles/Script.js 链接到这里。
// 修改或 git pull 后，在 Clash「订阅」页点击「重新激活订阅」。
function main(config, profileName) {
  if (!config || typeof config !== 'object' || Array.isArray(config)) return config;
  const prev = config.dns || {};
  const dns = {
    enable: true,
    ipv6: false,
    listen: prev.listen || '127.0.0.1:7874',
    'use-hosts': prev['use-hosts'] !== false,
    'prefer-h3': false,
    'respect-rules': true,
    'default-nameserver': ['223.5.5.5', '119.29.29.29', '114.114.114.114'],
    nameserver: ['https://dns.alidns.com/dns-query', 'https://doh.pub/dns-query'],
    fallback: [
      'https://dns.adguard-dns.com/dns-query',
      'https://cloudflare-dns.com/dns-query',
      'https://dns.google/dns-query',
    ],
    // 主 DNS 返回非 CN 或以下保留地址时采用 fallback；CN 地址本身并不保证正确。
    'fallback-filter': {
      geoip: true,
      'geoip-code': 'CN',
      ipcidr: ['240.0.0.0/4', '0.0.0.0/32'],
    },
    'nameserver-policy': {
      'rule-set:china_domain': ['223.5.5.5', '119.29.29.29'],
    },
    // 独立解析节点域名，替换订阅中可能指向本机 DNS 的配置，避免循环依赖。
    'proxy-server-nameserver': ['https://dns.alidns.com/dns-query', '223.5.5.5'],
  };

  // 保留模式和过滤项，不继承订阅的旧 DNS 上游、分流及节点解析策略。
  for (const key of ['enhanced-mode', 'fake-ip-range', 'fake-ip-range6',
    'fake-ip-filter', 'fake-ip-filter-mode', 'fake-ip-ttl', 'cache-algorithm', 'use-system-hosts']) {
    if (prev[key] !== undefined) dns[key] = prev[key];
  }

  // 从 Merge 的明确 AI 域名规则生成策略，域名只维护一份。
  // 直接经所选 AI 节点查询境外 DoH，避免错误的 CN 答案绕过 fallback-filter。
  const aiDns = [
    'https://cloudflare-dns.com/dns-query#🤖 AI服务',
    'https://dns.google/dns-query#🤖 AI服务',
  ];
  for (const rule of config.rules || []) {
    const [type, domain, target] = rule.split(',');
    if (target !== '🤖 AI服务') continue;
    if (type === 'DOMAIN') dns['nameserver-policy'][domain] = aiDns;
    if (type === 'DOMAIN-SUFFIX') dns['nameserver-policy']['+.' + domain] = aiDns;
  }
  config.dns = dns;
  return config;
}
