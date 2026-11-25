// FCF Budget – Cloudflare Worker
// Liefert die App aus und leitet Anfragen an das private GitHub-Repo weiter.
// Anmeldung: Cloudflare Access (E-Mail + Einmalcode). Der GitHub-Schlüssel liegt nur hier (Secret GH_TOKEN).
//
// Variablen (Worker → Settings → Variables and Secrets):
//   GH_TOKEN     (Secret) Fine-grained Token, nur Repo fcf-budget, Contents: Read and write
//   TEAM_DOMAIN  z. B. fcfrauenfeld.cloudflareaccess.com
//   POLICY_AUD   "Application Audience (AUD) Tag" der Access-Anwendung
//   REPO         optional, Standard rggyh95wwz-netizen/fcf-budget
//   APP_URL      optional, Standard https://rggyh95wwz-netizen.github.io/fcf-budget-app/

const REPO_DEFAULT = 'rggyh95wwz-netizen/fcf-budget';
const APP_DEFAULT = 'https://rggyh95wwz-netizen.github.io/fcf-budget-app/';
const SHA = '[0-9a-f]{40}', REF = '[A-Za-z0-9._-]+';
const ALLOWED = [
  ['GET', new RegExp(`^$`)],
  ['GET', new RegExp(`^/git/ref/heads/${REF}$`)],
  ['GET', new RegExp(`^/git/trees/${SHA}$`)],
  ['GET', new RegExp(`^/git/blobs/${SHA}$`)],
  ['GET', new RegExp(`^/git/commits/${SHA}$`)],
  ['POST', /^\/git\/trees$/],
  ['POST', /^\/git\/commits$/],
  ['PATCH', new RegExp(`^/git/refs/heads/${REF}$`)],
];

export default {
  async fetch(req, env) {
    const url = new URL(req.url);
    const email = await verifyAccess(req, env);
    if (!email) return new Response('Nicht angemeldet. Bitte die Seite neu laden und mit E-Mail-Code anmelden.', {status: 403});
    const repo = env.REPO || REPO_DEFAULT;

    if (url.pathname === '/api/me') return json({email, repo, push: true});

    if (url.pathname === '/api/repo' || url.pathname.startsWith('/api/repo/')) {
      const sub = url.pathname.slice('/api/repo'.length);
      if (!ALLOWED.some(([m, re]) => m === req.method && re.test(sub))) return json({message: 'nicht erlaubt'}, 403);
      const init = {method: req.method, headers: {
        Authorization: `Bearer ${env.GH_TOKEN}`, Accept: 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28', 'User-Agent': 'fcf-budget-worker'}};
      if (req.method !== 'GET') { init.body = await req.text(); init.headers['Content-Type'] = 'application/json'; }
      const r = await fetch(`https://api.github.com/repos/${repo}${sub}${url.search}`, init);
      const body = await r.text();
      // Die App sieht immer Schreibrechte, wenn der Worker-Schlüssel sie hat.
      return new Response(body, {status: r.status, headers: {'content-type': 'application/json', 'cache-control': 'no-store'}});
    }

    if (url.pathname === '/' || url.pathname === '/index.html') {
      const r = await fetch(env.APP_URL || APP_DEFAULT, {cf: {cacheTtl: 60}});
      return new Response(r.body, {status: r.status, headers: {'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store'}});
    }
    return new Response('Nicht gefunden', {status: 404});
  }
};

const json = (o, status = 200) => new Response(JSON.stringify(o), {status, headers: {'content-type': 'application/json', 'cache-control': 'no-store'}});

// Prüft das Anmelde-Token von Cloudflare Access (signiertes JWT). Ohne gültiges Token: kein Zugriff.
let certs = null, certsAt = 0;
async function verifyAccess(req, env) {
  if (!env.TEAM_DOMAIN || !env.POLICY_AUD) return null;
  const cookie = (req.headers.get('cookie') || '').match(/(?:^|;\s*)CF_Authorization=([^;]+)/);
  const token = req.headers.get('cf-access-jwt-assertion') || (cookie && cookie[1]);
  if (!token) return null;
  try {
    const [h, p, s] = token.split('.');
    const dec = x => JSON.parse(new TextDecoder().decode(b64(x)));
    const head = dec(h), pay = dec(p);
    const team = env.TEAM_DOMAIN.replace(/^https?:\/\//, '').replace(/\/$/, '');
    if (pay.iss !== `https://${team}`) return null;
    if (!(Array.isArray(pay.aud) ? pay.aud : [pay.aud]).includes(env.POLICY_AUD)) return null;
    if (!pay.exp || pay.exp * 1000 < Date.now()) return null;
    if (!certs || Date.now() - certsAt > 3600e3) { certs = (await (await fetch(`https://${team}/cdn-cgi/access/certs`)).json()).keys; certsAt = Date.now(); }
    const jwk = certs.find(k => k.kid === head.kid); if (!jwk) { certs = null; return null; }
    const key = await crypto.subtle.importKey('jwk', jwk, {name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256'}, false, ['verify']);
    const ok = await crypto.subtle.verify('RSASSA-PKCS1-v1_5', key, b64(s), new TextEncoder().encode(`${h}.${p}`));
    return ok ? (pay.email || null) : null;
  } catch (e) { return null; }
}
function b64(s) { s = s.replace(/-/g, '+').replace(/_/g, '/'); while (s.length % 4) s += '='; return Uint8Array.from(atob(s), c => c.charCodeAt(0)); }
