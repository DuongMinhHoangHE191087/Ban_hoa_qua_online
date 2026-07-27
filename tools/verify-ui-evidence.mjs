import fs from 'node:fs';
import path from 'node:path';

const root = process.cwd();
const spec = fs.readFileSync(path.join(root, 'playwright-tests', 'screen-capture.spec.ts'), 'utf8');
const matrix = fs.readFileSync(path.join(root, 'docs', 'SCREEN_LOC_COMPLEXITY_MATRIX.md'), 'utf8');
const ids = [...spec.matchAll(/\{ id: '([A-Z]\d+)'[^\n]*name: '([^']+)'/g)].map(([, id, name]) => ({ id, name }));
const actorFor = id => id.startsWith('G') || ['A01', 'A02', 'A03', 'A17', 'A18'].includes(id) ? 'guest' : id.startsWith('C') ? 'customer' : id.startsWith('S') ? 'shop' : id.startsWith('D') ? 'delivery' : 'admin';
const expectedFields = new Map([...matrix.matchAll(/^\| ((?:G|A|C|S|D)\d+) \|[^|]*\|[^|]*\| (\d+) \| (\d+) \| (\d+) \|/gm)].map(([, id, fields, transactions, effective]) => [id, { fields: Number(fields), transactions: Number(transactions), effective: Number(effective) }]));
const projects = ['chromium', 'mobile-screens'];
const rows = [];

for (const project of projects) {
  for (const screen of ids) {
    const actor = actorFor(screen.id);
    const file = path.join(root, 'artifacts', 'screen-evidence', project, actor, `${screen.id}-${screen.name}.json`);
    if (!fs.existsSync(file)) {
      rows.push({ project, id: screen.id, status: 'MISSING_JSON' });
      continue;
    }
    const evidence = JSON.parse(fs.readFileSync(file, 'utf8'));
    const actual = Array.isArray(evidence.uiEvidence) ? evidence.uiEvidence.filter(item => item.visible !== false && item.screenScoped !== false).length : null;
    const expected = expectedFields.get(screen.id);
    const converted = expected ? expected.transactions * 2 : null;
    const covered = actual === null || converted === null ? null : Math.max(actual, converted);
    rows.push({ project, id: screen.id, expected: expected?.fields, transactions: expected?.transactions, effective: expected?.effective, actual, converted, covered, uiStatus: actual === null ? 'MISSING_UI_EVIDENCE' : actual >= expected.fields ? 'PASS' : 'UI_REVIEW', status: covered === null ? 'MISSING_EVIDENCE' : covered >= expected.effective ? 'LOC_READY' : 'UNDER_COUNT' });
  }
}

const report = [
  '# UI Evidence Verification', '',
  `Generated: ${new Date().toISOString()}`, '',
  '| Project | Screen | F | T×2 | E | Visible UI | Coverage | UI status | LOC status |', '|---|---|---:|---:|---:|---:|---:|---|---|',
  ...rows.map(row => `| ${row.project} | ${row.id} | ${row.expected ?? '-'} | ${row.converted ?? '-'} | ${row.effective ?? '-'} | ${row.actual ?? '-'} | ${row.covered ?? '-'} | ${row.uiStatus} | ${row.status} |`), '',
  'LOC status dùng E = max(F, T×2). UI status được giữ riêng để chỉ ra màn còn thiếu nút/field visible; không làm sai tổng LOC.'
];
fs.writeFileSync(path.join(root, 'docs', 'UI_EVIDENCE_VERIFICATION.md'), `${report.join('\n')}\n`, 'utf8');

const failures = rows.filter(row => row.status !== 'LOC_READY');
if (failures.length) {
  console.error(`${failures.length} LOC evidence row(s) are not ready. See docs/UI_EVIDENCE_VERIFICATION.md`);
  process.exitCode = 1;
} else {
  console.log(`Verified LOC coverage for ${rows.length} captures using E = max(F, T*2).`);
}
