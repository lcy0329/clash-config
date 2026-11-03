// node scripts/verify-dns.js — 无第三方依赖；运行 Clash 实际使用的全局脚本。
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const context = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../clash-verge/script.js'), 'utf8'), context);
const main = context.main;
const plain = value => JSON.parse(JSON.stringify(value));

const original = {
  dns: {
    'enhanced-mode': 'fake-ip',
    'fake-ip-range': '198.18.0.1/16',
    'fake-ip-filter': ['*.lan', 'music.163.com'],
    'fake-ip-filter-mode': 'blacklist',
    'use-system-hosts': false,
    'proxy-server-nameserver': ['udp://127.0.0.1:7874'],
    'proxy-server-nameserver-policy': {'+.example.com': 'udp://127.0.0.1:7874'},
    'nameserver-policy': {'+.openai.com': 'udp://127.0.0.1:7874'},
    'direct-nameserver': ['udp://127.0.0.1:7874'],
  },
  rules: ['DOMAIN-SUFFIX,openai.com,🤖 AI服务', 'DOMAIN,host.livekit.cloud,🤖 AI服务',
    'DOMAIN-SUFFIX,github.com,🐙 GitHub'],
  'proxy-groups': [{name: '🤖 AI服务', type: 'select', proxies: ['REJECT']}],
  tun: {enable: true},
};
const result = plain(main(structuredClone(original)));
for (const [key, value] of Object.entries(original)) {
  if (key !== 'dns') assert.deepEqual(result[key], value, 'DNS 脚本改动了 ' + key);
}
for (const key of ['enhanced-mode', 'fake-ip-range', 'fake-ip-filter', 'fake-ip-filter-mode', 'use-system-hosts']) {
  assert.deepEqual(result.dns[key], original.dns[key], '订阅 DNS 兼容字段丢失：' + key);
}
assert(!JSON.stringify(result.dns).includes('udp://127.0.0.1:7874'), '旧自指 DNS 仍被继承');
assert.equal(result.dns.listen, '127.0.0.1:7874');
const policy = result.dns['nameserver-policy'];
assert.deepEqual(Object.keys(policy).sort(), ['rule-set:china_domain', '+.openai.com', 'host.livekit.cloud'].sort());
for (const key of ['+.openai.com', 'host.livekit.cloud']) {
  assert.deepEqual(policy[key], ['https://cloudflare-dns.com/dns-query#🤖 AI服务', 'https://dns.google/dns-query#🤖 AI服务']);
}
assert(!Object.hasOwn(main({}).dns, 'enhanced-mode'), '脚本擅自切换了 DNS 模式');
assert(!Object.hasOwn(main({}).dns, 'fake-ip-range'), '脚本擅自增加了 Fake-IP 网段');
assert.equal(main(null), null);
console.log('PASS: AI DNS 策略、Fake-IP 兼容、旧 DNS 替换及非 DNS 配置保持');
