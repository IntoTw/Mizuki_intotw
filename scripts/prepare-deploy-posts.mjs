import fs from 'node:fs';
import path from 'node:path';
import matter from 'gray-matter';
import { execFileSync } from 'node:child_process';
const [source, destination] = process.argv.slice(2);
if (!source || !destination || !fs.statSync(source).isDirectory()) throw new Error('Expected source and staging destination');
// The caller supplies an isolated temporary build directory, never the notes directory.
if (path.resolve(destination) === path.resolve(source)) throw new Error('Source and destination must differ');
fs.rmSync(destination, { recursive: true, force: true });
fs.cpSync(source, destination, { recursive: true, dereference: true });
let count = 0;
function walk(dir) {
  for (const name of fs.readdirSync(dir)) {
    const file = path.join(dir, name);
    if (fs.statSync(file).isDirectory()) { walk(file); continue; }
    if (!/\.mdx?$/i.test(name)) continue;
    const raw = fs.readFileSync(file, 'utf8');
    let parsed;
    if (raw.startsWith('+++')) {
      const match = raw.match(/^\+\+\+\r?\n([\s\S]*?)\r?\n\+\+\+[^\n]*(?:\n|$)/);
      if (!match) throw new Error(`Unclosed TOML frontmatter: ${file}`);
      // Python 3.11+ supplies tomllib; no extra application dependency needed.
      const data = JSON.parse(execFileSync('python3', ['-c',
        'import sys,json,tomllib; print(json.dumps(tomllib.loads(sys.stdin.read()), default=lambda x:x.isoformat()))'
      ], { input: match[1], encoding: 'utf8' }));
      parsed = { data, content: raw.slice(match[0].length) };
    } else {
      parsed = matter(raw);
    }
    const d = parsed.data;
    d.title ??= d.ddtitle;
    d.published ??= d.date;
    if (d.lastmod != null) d.updated ??= d.lastmod;
    d.image ??= d.featuredImage ?? d.featuredImagePreview ?? '';
    d.category ??= Array.isArray(d.categories) ? d.categories[0] ?? '' : d.categories ?? '';
    if (!d.title || !d.published) throw new Error(`Missing title/date: ${file}`);
    for (const field of ['published', 'updated']) {
      if (d[field] == null) continue;
      let value = new Date(d[field]);
      if (Number.isNaN(value.getTime()) && field === 'published' && d.updated != null) {
        value = new Date(d.updated);
        if (!Number.isNaN(value.getTime())) console.warn(`Invalid published date in ${file}; using updated date`);
      }
      if (Number.isNaN(value.getTime())) throw new Error(`Invalid ${field}: ${file}`);
      d[field] = value;
    }
    fs.writeFileSync(file, matter.stringify(parsed.content, d));
    count++;
  }
}
walk(destination);
if (!count) throw new Error('No Markdown posts found');
console.log(`Prepared ${count} posts; original notes unchanged. URL/shortcode migration still needs review.`);
