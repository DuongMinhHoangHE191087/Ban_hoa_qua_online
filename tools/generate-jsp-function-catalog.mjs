import fs from 'node:fs';
import path from 'node:path';

const root = process.cwd();
const sourceRoot = path.join(root, 'web', 'WEB-INF', 'jsp');
const output = path.join(root, 'docs', 'JSP_FUNCTION_CATALOG.md');
const functions = new Map();
const files = [];

function add(key, type, file, sample) {
  if (!key) return;
  const row = functions.get(key) || { key, type, occurrences: 0, files: new Set(), samples: new Set() };
  row.occurrences += 1;
  row.files.add(path.relative(root, file).replaceAll('\\', '/'));
  row.samples.add(sample.replace(/\s+/g, ' ').slice(0, 180));
  functions.set(key, row);
}

function walk(dir) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const file = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(file);
    else if (/\.jspf?$/.test(entry.name)) files.push(file);
  }
}

walk(sourceRoot);
for (const file of files) {
  const source = fs.readFileSync(file, 'utf8');
  for (const match of source.matchAll(/(?:onclick|onchange|onsubmit)\s*=\s*["']([^"']+)["']/gi)) {
    const expression = match[1];
    const handler = expression.match(/(?:window\[['"]?([^'"\]]+)|([A-Za-z_$][\w$]*))\s*\(/);
    add(handler?.[1] || handler?.[2] || expression, 'client-handler', file, expression);
  }
  for (const match of source.matchAll(/<form\b[^>]*\baction\s*=\s*["']([^"']+)["'][^>]*>/gi)) {
    add(match[1], 'form-action', file, match[0]);
  }
}

const rows = [...functions.values()].sort((a, b) => a.key.localeCompare(b.key));
const lines = [
  '# JSP/JSPF Function Catalog', '',
  'Nguồn: `web/WEB-INF/jsp/**/*.jsp` và `*.jspf`. Các occurrence cùng function key là cùng chức năng; không tính lặp theo từng product/order item.', '',
  `- JSP/JSPF files scanned: ${files.length}`,
  `- Unique function/form keys: ${rows.length}`,
  '', '| Function key | Type | Occurrences | Source files | Sample |', '|---|---|---:|---|---|',
  ...rows.map(row => `| \`${row.key.replaceAll('|', '\\|')}\` | ${row.type} | ${row.occurrences} | ${[...row.files].slice(0, 4).join('<br>')} | ${[...row.samples][0].replaceAll('|', '\\|')} |`), '',
  'Quy tắc: function key dùng để đánh số representative trong `uiEvidence`; `duplicateCount` chỉ mô tả số instance render, không cộng thêm LOC.'
];
fs.writeFileSync(output, `${lines.join('\n')}\n`, 'utf8');
console.log(`Generated ${path.relative(root, output)} with ${rows.length} unique keys from ${files.length} files.`);
