import fs from 'node:fs';
import path from 'node:path';

const root = process.cwd();
const matrixPath = path.join(root, 'docs', 'SCREEN_LOC_COMPLEXITY_MATRIX.md');
const output = path.join(root, 'docs', 'LOC_QUALITY_ASSESSMENT.md');
const source = fs.readFileSync(matrixPath, 'utf8');
const baseFor = { L1: 60, L2: 90, L3: 120, L4: 150, L5: 180, L6: 210, L7: 240 };
const failedIds = new Set(['G01', 'G04', 'G06', 'G07']);
// Best is reserved for screens whose concrete flow is covered by the
// transaction/security evidence, not merely because the screen has many fields.
const bestIds = new Set(['C02', 'C07', 'C08', 'S05', 'S10', 'S11', 'S13', 'D03', 'A07', 'A13']);
const rows = [];

for (const line of source.split(/\r?\n/)) {
  const m = line.match(/^\| ((?:G|A|C|S|D)\d+) \| ([^|]+) \| ([^|]+) \| (\d+) \| (\d+) \| (\d+) \| (L\d) \| (\d+) \| ([^|]+) \|$/);
  if (!m) continue;
  const [, id, actor, name, f, t, e, level, normal] = m;
  const base = baseFor[level];
  let quality = 'Normal', rate = .75, reason = 'Có render, input/route và xử lý dữ liệu; cần giữ evidence error/permission theo checklist.';
  if (failedIds.has(id)) {
    quality = 'Failed'; rate = .5; reason = 'Màn public/static hoặc chưa có đủ unhappy-path/transaction evidence để chốt Normal.';
  } else if (bestIds.has(id)) {
    quality = 'Best'; rate = 1; reason = 'Flow rủi ro cao có transaction/security test hoặc evidence rollback/idempotency/concurrency/audit.';
  }
  rows.push({ id, actor: actor.trim(), name: name.trim(), f: +f, t: +t, e: +e, level, base, quality, rate, evaluated: Math.round(base * rate), reason });
}
if (rows.length !== 61) throw new Error(`Expected 61 rows, found ${rows.length}`);
const sum = key => rows.reduce((n, row) => n + row[key], 0);
const totalAt = rate => rows.reduce((n, row) => n + Math.round(row.base * rate), 0);
const qualityCount = quality => rows.filter(row => row.quality === quality).length;
const lines = [
  '# LOC Quality Assessment', '',
  '## 1. Quy tắc chốt phần trăm', '',
  '| Mức | Rate | Chỉ được dùng khi | Không được dùng khi |',
  '|---|---:|---|---|',
  '| Failed | 50% | Chỉ chứng minh render/happy path hoặc còn thiếu validation/error/authorization | Không dùng để mô tả flow đã đủ test transaction |',
  '| Normal | 75% | Có route/JSP, input validation, quyền, lỗi, đọc/ghi dữ liệu hoặc chứng minh rõ màn read-only | Không gọi Normal chỉ vì ảnh đẹp |',
  '| Best | 100% | Normal + tối ưu UX/nghiệp vụ và test/evidence transaction safety, audit, idempotency/concurrency khi phù hợp | Không dùng nếu chỉ có screenshot/DOM |',
  '',
  'Công thức: `E = max(F, T × 2)` → Level → `Evaluated LOC = Base LOC × Quality Rate`. `Normal` làm tròn theo bảng Level.', '',
  '## 2. Đánh giá từng màn theo code/evidence hiện có', '',
  '| ID | Actor | Màn hình | F | T | E | Level | Base LOC | Quality | Rate | Evaluated LOC | Lý do kiểm tra |',
  '|---|---|---|---:|---:|---:|---:|---:|---|---:|---:|---|',
  ...rows.map(row => `| ${row.id} | ${row.actor} | ${row.name} | ${row.f} | ${row.t} | ${row.e} | ${row.level} | ${row.base} | ${row.quality} | ${row.rate * 100}% | ${row.evaluated} | ${row.reason} |`),
  '', '## 3. Tổng hợp báo cáo', '',
  '| Chỉ số | Giá trị |', '|---|---:|',
  `| Tổng màn | ${rows.length} |`, `| Failed screens | ${qualityCount('Failed')} |`, `| Normal screens | ${qualityCount('Normal')} |`, `| Best screens | ${qualityCount('Best')} |`,
  `| Failed LOC nếu toàn bộ dự án ở 50% | ${totalAt(.5)} |`,
  `| Normal LOC nếu toàn bộ dự án ở 75% | ${totalAt(.75)} |`,
  `| Best LOC nếu toàn bộ dự án ở 100% | ${sum('base')} |`,
  `| Evaluated LOC theo quality assessment hiện tại | ${sum('evaluated')} |`, '',
  '## 4. Kết luận dùng để báo cáo', '',
  'Số nên báo cáo là **Evaluated LOC theo quality assessment hiện tại**, vì đây là kết quả sau khi đọc code và đối chiếu evidence. Không lấy Best LOC toàn bộ nếu các màn chưa có đủ bằng chứng Best. Khi bổ sung test/evidence cho một màn, chỉ nâng rate của màn đó và chạy lại script để cập nhật tổng.', '',
  'Evidence nền: `SCREEN_PROCESS_ANALYSIS.md`, `TRANSACTION_TEST_RUN_2026-07-20.md`, `TRANSACTION_EVIDENCE_MAP.md`, `JSP_FUNCTION_CATALOG.md`, ảnh/JSON trong `artifacts/`.'
];
fs.writeFileSync(output, `${lines.join('\n')}\n`, 'utf8');
console.log(`Generated ${path.relative(root, output)} for ${rows.length} screens.`);
