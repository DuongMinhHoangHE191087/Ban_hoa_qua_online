import fs from 'node:fs';
import path from 'node:path';

const root = process.cwd();
const spec = fs.readFileSync(path.join(root, 'playwright-tests', 'screen-capture.spec.ts'), 'utf8');
const ids = [...spec.matchAll(/\{ id: '([A-Z]\d+)'[^\n]*name: '([^']+)'/g)].map(([, id, name]) => ({ id, name }));
const projects = ['chromium', 'mobile-screens'];
const actorFor = id => id.startsWith('G') || ['A01', 'A02', 'A03', 'A17', 'A18'].includes(id) ? 'guest' : id.startsWith('C') ? 'customer' : id.startsWith('S') ? 'shop' : id.startsWith('D') ? 'delivery' : 'admin';
const exists = relative => fs.existsSync(path.join(root, relative));
const rows = projects.flatMap(project => ids.map(screen => {
  const actor = actorFor(screen.id);
  const base = `artifacts/screenshots/${project}/${actor}/${screen.id}-${screen.name}`;
  return { project, ...screen, actor, image: exists(`${base}.png`) || exists(`${base}-viewport.png`), evidence: exists(`artifacts/screen-evidence/${project}/${actor}/${screen.id}-${screen.name}.json`) };
}));
const missing = rows.filter(row => !row.image || !row.evidence);
const lines = ['# Screen evidence index', '', `Generated: ${new Date().toISOString()}`, '', `- Manifest screens: ${ids.length}`, `- Expected captures: ${rows.length}`, `- Complete captures: ${rows.length - missing.length}`, `- Missing artifacts: ${missing.length}`, '', '| Project | ID | Actor | Screenshot | Network/console JSON |', '|---|---|---|---|---|', ...rows.map(row => `| ${row.project} | ${row.id} | ${row.actor} | ${row.image ? 'PASS' : 'MISSING'} | ${row.evidence ? 'PASS' : 'MISSING'} |`)];
fs.writeFileSync(path.join(root, 'docs', 'SCREEN_EVIDENCE_INDEX.md'), `${lines.join('\n')}\n`, 'utf8');
if (missing.length) { console.error(`Missing ${missing.length} artifact(s). See docs/SCREEN_EVIDENCE_INDEX.md`); process.exitCode = 1; }
else console.log(`Verified ${rows.length} screen captures with screenshot and JSON evidence.`);
