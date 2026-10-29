// サイト監視の LINE 公式アカウントの返事係（Cloudflare Workers）。
// 公式アカウントにメッセージが届いたら、6サイトをその場で開いて確かめ、今の状態をリンクつきで返す。
// 見張るサイトは GitHub の sites.tsv、SSL の残り日数は毎朝の記録 status.json から読む（公開リポジトリなので鍵はいらない）。
// 秘密の値（wrangler secret put で入れる）：LINE_CHANNEL_SECRET（署名の確認）、LINE_CHANNEL_ACCESS_TOKEN（返事）
const RAW = 'https://raw.githubusercontent.com/fumiyukino/site-monitor/main/';
const ERROR_WORDS = /critical error|重大なエラー|Fatal error|Parse error|データベース接続確立エラー|Error establishing a database connection/i;

export default {
  async fetch(request, env, ctx) {
    if (request.method !== 'POST') return new Response('ok');
    const body = await request.text();
    if (!(await validSignature(body, request.headers.get('x-line-signature'), env.LINE_CHANNEL_SECRET)))
      return new Response('bad signature', { status: 401 });
    const events = JSON.parse(body).events || [];
    // LINE には先に 200 を返し、確かめと返事はそのあとで行う（確かめに数秒かかるため）
    ctx.waitUntil(Promise.all(events.filter(e => e.replyToken && ['message', 'follow'].includes(e.type))
      .map(async e => reply(env, e.replyToken, await statusText()))));
    return new Response('ok');
  },
};

async function validSignature(body, signature, secret) {
  if (!signature || !secret) return false;
  const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const mac = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(body));
  return btoa(String.fromCharCode(...new Uint8Array(mac))) === signature;
}

async function statusText() {
  const [tsv, daily] = await Promise.all([
    fetch(RAW + 'sites.tsv', { cf: { cacheTtl: 60 } }).then(r => r.text()),
    fetch(RAW + 'status.json', { cf: { cacheTtl: 300 } }).then(r => r.json()).catch(() => null),
  ]);
  const sites = tsv.split('\n').filter(l => l.trim() && !l.startsWith('#')).map(l => {
    const [name, url, ok] = l.split('\t');
    return { name, url, ok: ok.split('|') };
  });
  const ssl = Object.fromEntries((daily?.sites || []).map(s => [s.name, s.ssl_days]));
  const rows = await Promise.all(sites.map(check));
  const now = new Date().toLocaleString('ja-JP', { timeZone: 'Asia/Tokyo', month: 'numeric', day: 'numeric', hour: '2-digit', minute: '2-digit' });
  const bad = rows.filter(r => !r.ok).length;
  const lines = rows.map(r => {
    const days = ssl[r.name];
    const sslNote = days == null ? '' : days < 21 ? `　🔐SSL残り${days}日⚠️` : `　🔐SSL残り${days}日`;
    return `${r.ok ? '✅' : '⚠️'} ${r.name}${r.ok ? `（${r.ms}ms）` : `：${r.note}`}${sslNote}\n${r.url}`;
  });
  return `📊 サイトの状態（${now}）\n${bad ? `⚠️ ${bad}件に異常があります` : 'すべて正常です'}\n\n${lines.join('\n\n')}`
    + `\n\nSSL の残り日数は毎朝9時の記録です。`;
}

async function check(site) {
  const started = Date.now();
  try {
    const res = await fetch(site.url, { redirect: 'manual', signal: AbortSignal.timeout(20000), headers: { 'user-agent': 'site-monitor-line (fumiyukino)' } });
    const ms = Date.now() - started;
    const code = String(res.status);
    if (!site.ok.includes(code)) return { ...site, ok: false, ms, note: `HTTP ${code}（期待値 ${site.ok.join('|')}）` };
    if (code === '200' && ERROR_WORDS.test(await res.text())) return { ...site, ok: false, ms, note: 'ページに PHP / DB のエラーが出ている' };
    return { ...site, ok: true, ms };
  } catch (err) {
    return { ...site, ok: false, ms: Date.now() - started, note: err.name === 'TimeoutError' ? '20秒たっても応答がない' : '開けない（' + err.message + '）' };
  }
}

async function reply(env, replyToken, text) {
  await fetch('https://api.line.me/v2/bot/message/reply', {
    method: 'POST',
    headers: { 'content-type': 'application/json', authorization: `Bearer ${env.LINE_CHANNEL_ACCESS_TOKEN}` },
    body: JSON.stringify({ replyToken, messages: [{ type: 'text', text: text.slice(0, 5000) }] }),
  });
}
