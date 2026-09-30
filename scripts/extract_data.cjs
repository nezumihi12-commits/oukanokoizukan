// Usage: node scripts/extract_data.cjs path/to/trusted-index.html
// Extract only from the owner's trusted source. Node vm is not a security boundary.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '..');
if (!process.argv[2]) throw new Error('Supply the trusted original HTML file path.');
const bytes = fs.readFileSync(process.argv[2]);
const html = bytes.toString('utf8');
const match = html.match(/const GENERA = (\[[\s\S]*?\n\]);/);
if (!match) throw new Error('GENERA not found');
const genera = JSON.parse(JSON.stringify(vm.runInNewContext(match[1], {}, {timeout: 1000})));
if (genera.length !== 307 || new Set(genera.map(g => g.latin)).size !== 307) throw new Error('Dataset changed: review expected counts and migrations first.');
const start = html.indexOf('function getJpInfo(');
const end = html.indexOf('function buildQ(', start);
if (start < 0 || end < 0) throw new Error('getJpInfo not found');
const context = vm.createContext({});
vm.runInContext(html.slice(start, end), context, {timeout: 1000});
const resources = {
  'App/Resources/genera.json': genera,
  'App/Resources/japaneseAnswers.json': Object.fromEntries(genera.map(g => [g.latin, context.getJpInfo(g)]))
};
const manifestPath = path.join(root, 'docs/source-manifest.json');
const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
manifest.sha256 = crypto.createHash('sha256').update(bytes).digest('hex');
manifest.attachment = path.basename(process.argv[2]);
manifest.count = genera.length;
manifest.resources = manifest.resources || {};
for (const [relative, value] of Object.entries(resources)) {
  const output = JSON.stringify(value, null, 2);
  fs.writeFileSync(path.join(root, relative), output);
  manifest.resources[relative] = crypto.createHash('sha256').update(output).digest('hex');
}
manifest.upstreamComparison = 'Re-extracted locally; compare with upstream again before release.';
fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2));
console.log(`Extracted ${genera.length} genera and original Japanese answer candidates.`);
