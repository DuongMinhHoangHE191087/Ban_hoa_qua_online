import fs from 'node:fs';
import path from 'node:path';

const root = process.cwd();
const matrix = fs.readFileSync(path.join(root, 'docs', 'SCREEN_LOC_COMPLEXITY_MATRIX.md'), 'utf8');
const output = path.join(root, 'docs', 'loc-evidence-dashboard.html');
const actorFor = id => id.startsWith('G') || ['A01', 'A02', 'A03', 'A17', 'A18'].includes(id) ? 'guest' : id.startsWith('C') ? 'customer' : id.startsWith('S') ? 'shop' : id.startsWith('D') ? 'delivery' : 'admin';
const slug = value => value.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
const baseFor = { L1: 60, L2: 90, L3: 120, L4: 150, L5: 180, L6: 210, L7: 240 };
const rows = [];
const artifactFor = (folder, id, suffix) => {
  if (!fs.existsSync(folder)) return null;
  const file = fs.readdirSync(folder).find(name => name.startsWith(`${id}-`) && name.endsWith(suffix));
  return file ? path.join(folder, file) : null;
};

for (const line of matrix.split(/\r?\n/)) {
  const m = line.match(/^\| ((?:G|A|C|S|D)\d+) \| ([^|]+) \| ([^|]+) \| (\d+) \| (\d+) \| (\d+) \| (L\d) \| (\d+) \| ([^|]+) \|$/);
  if (!m) continue;
  const [, id, actor, name, f, t, e, level, normal, seam] = m;
  const screen = slug(name);
  const actorDir = actorFor(id);
  const evidenceFolder = path.join(root, 'artifacts', 'screen-evidence', 'chromium', actorDir);
  const evidencePath = artifactFor(evidenceFolder, id, '.json');
  const evidence = evidencePath && fs.existsSync(evidencePath) ? JSON.parse(fs.readFileSync(evidencePath, 'utf8')) : {};
  const ui = Array.isArray(evidence.uiEvidence) ? evidence.uiEvidence.filter(x => x.visible !== false && x.screenScoped !== false).length : 0;
  const base = baseFor[level];
  const converted = +t * 2;
  const screenshotFolder = path.join(root, 'artifacts', 'screenshots', 'chromium', actorDir);
  const annotatedFile = artifactFor(screenshotFolder, id, '-annotated.png');
  const evidenceFile = evidencePath ? path.basename(evidencePath) : `${id}-${screen}.json`;
  rows.push({ id, actor: actor.trim(), name: name.trim(), f: +f, t: +t, e: +e, level, base, failed: Math.round(base * .5), normal: +normal, best: base, seam: seam.trim(), ui, converted, coverage: Math.max(ui, converted), uiStatus: ui >= +f ? 'PASS' : 'UI_REVIEW', status: Math.max(ui, converted) >= +e ? 'LOC_READY' : 'UNDER_COUNT', annotated: `../artifacts/screenshots/chromium/${actorDir}/${annotatedFile ? path.basename(annotatedFile) : `${id}-${screen}-annotated.png`}`, evidence: `../artifacts/screen-evidence/chromium/${actorDir}/${evidenceFile}` });
}
if (rows.length !== 61) throw new Error(`Matrix row count is ${rows.length}, expected 61`);

const data = JSON.stringify(rows).replace(/</g, '\\u003c');
const html = `<!doctype html><html lang="vi"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>LOC Evidence Dashboard</title>
<style>body{margin:0;background:#f5f7fb;color:#172033;font:14px Segoe UI,Arial}main{max-width:1500px;margin:auto;padding:28px}h1{margin:0 0 6px}.muted{color:#637083}.formula{margin:18px 0;padding:14px;background:#172033;color:#fff;border-radius:10px}.cards{display:flex;gap:12px;flex-wrap:wrap;margin:18px 0}.card{flex:1;min-width:140px;background:#fff;border:1px solid #dbe3ee;border-radius:10px;padding:14px}.value{display:block;font-size:24px;font-weight:700;margin-top:5px}input,select{padding:9px;border:1px solid #dbe3ee;border-radius:7px;margin:0 8px 14px 0}.wrap{overflow:auto;background:#fff;border:1px solid #dbe3ee;border-radius:10px}table{width:100%;border-collapse:collapse;min-width:1050px}th,td{padding:9px 10px;border-bottom:1px solid #dbe3ee;text-align:left;white-space:nowrap}th{background:#edf3fb;position:sticky;top:0}.pill{border-radius:99px;padding:3px 7px;font-size:11px;font-weight:700}.pass{color:#087443;background:#ddf7e9}.under{color:#a15c00;background:#fff0d4}a{color:#2457a6;text-decoration:none}tfoot{font-weight:700;background:#f0f5fb}</style></head><body><main>
<h1>LOC &amp; Evidence Dashboard</h1><div class="muted">F/T/E/Level lấy từ ma trận chuẩn; DOM evidence chỉ dùng kiểm tra minh chứng.</div><div class="formula">E = max(F, T × 2) | Normal LOC = Base LOC × 75%</div>
<section class="cards"><div class="card">Số màn<span class="value" id="screens">0</span></div><div class="card">Tổng F<span class="value" id="f">0</span></div><div class="card">Tổng T<span class="value" id="t">0</span></div><div class="card">Failed LOC<span class="value" id="failed">0</span></div><div class="card">Normal LOC<span class="value" id="normal">0</span></div><div class="card">Best LOC<span class="value" id="best">0</span></div></section>
<input id="q" placeholder="Tìm ID, actor, màn hình"><select id="s"><option value="all">Tất cả evidence</option><option>LOC_READY</option><option>UNDER_COUNT</option><option>UI_REVIEW</option></select><div class="wrap"><table><thead><tr><th>ID</th><th>Actor</th><th>Màn hình</th><th>F</th><th>T</th><th>E</th><th>Level</th><th>Failed</th><th>Normal</th><th>Best</th><th>UI</th><th>T×2</th><th>Coverage</th><th>Status</th><th>Links</th></tr></thead><tbody id="body"></tbody><tfoot><tr><td colspan="3">TỔNG ĐANG HIỂN THỊ</td><td id="tf">0</td><td id="tt">0</td><td id="te">0</td><td></td><td id="tfailed">0</td><td id="tnormal">0</td><td id="tbest">0</td><td colspan="5"></td></tr></tfoot></table></div>
<p class="muted">Ảnh annotated đánh dấu representative function; JSON ghi duplicateCount. Xem <a href="JSP_FUNCTION_CATALOG.md">catalog hàm JSP</a> và <a href="LOC_QUALITY_ASSESSMENT.md">báo cáo quality/LOC hiện tại</a>. Transaction/DB phải đối chiếu thêm traceability matrix và test report.</p></main>
<script>const DATA=${data},nf=new Intl.NumberFormat('vi-VN'),sum=(a,k)=>a.reduce((n,x)=>n+x[k],0);const q=document.querySelector('#q'),s=document.querySelector('#s'),body=document.querySelector('#body');function render(){const z=q.value.toLowerCase(),st=s.value,a=DATA.filter(x=>(!z||[x.id,x.actor,x.name,x.seam].join(' ').toLowerCase().includes(z))&&(st==='all'||x.status===st||x.uiStatus===st));body.innerHTML=a.map(x=>'<tr><td><b>'+x.id+'</b></td><td>'+x.actor+'</td><td>'+x.name+'</td><td>'+x.f+'</td><td>'+x.t+'</td><td>'+x.e+'</td><td>'+x.level+'</td><td>'+nf.format(x.failed)+'</td><td>'+nf.format(x.normal)+'</td><td>'+nf.format(x.best)+'</td><td>'+x.ui+'/'+x.f+'</td><td>'+x.converted+'</td><td>'+x.coverage+'/'+x.e+'</td><td><span class="pill '+(x.status==='LOC_READY'?'pass':'under')+'">'+x.status+'</span> <span class="muted">'+x.uiStatus+'</span></td><td><a href="'+x.annotated+'">Annotated</a> · <a href="'+x.evidence+'">JSON</a></td></tr>').join('');[['tf','f'],['tt','t'],['te','e'],['tfailed','failed'],['tnormal','normal'],['tbest','best']].forEach(([i,k])=>document.getElementById(i).textContent=nf.format(sum(a,k)))}[['screens','length'],['f','f'],['t','t'],['failed','failed'],['normal','normal'],['best','best']].forEach(([i,k])=>document.getElementById(i).textContent=nf.format(k==='length'?DATA.length:sum(DATA,k)));q.oninput=render;s.onchange=render;render();</script></body></html>`;
fs.writeFileSync(output, html, 'utf8');
console.log(`Generated ${path.relative(root, output)} from ${rows.length} matrix rows.`);
