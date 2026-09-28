const base = process.env.BLOG_URL || 'http://127.0.0.1:8080';
const check = async (url, status = 200) => {
  const response = await fetch(new URL(url, base), { signal: AbortSignal.timeout(10000) });
  if (response.status !== status) throw new Error(`${url}: expected ${status}, got ${response.status}`);
  console.log(`${status} ${url}`);
  return response;
};
const home = await (await check('/')).text();
await check('/healthz');
await check('/pagefind/pagefind.js');
await check('/__mizuki_missing_route__/', 404);
const asset = home.match(/(?:src|href)="([^" ]*\/_astro\/[^" ]+)"/);
if (!asset) throw new Error('No built Astro asset found');
await check(new URL(asset[1], base).pathname);
const article = home.match(/href="([^" ]*\/posts\/[^" ]+)"/);
if (!article) throw new Error('No article link found');
await check(new URL(article[1], base).pathname);
console.log('Container HTTP checks passed.');
