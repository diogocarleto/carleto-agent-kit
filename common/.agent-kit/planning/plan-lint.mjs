// Plan gate: every Execution Plan phase, spikes included, carries a valid `Complexity:` (rubric:
// .agent-kit/common/process/planning/plan-shaping.md -> Phase complexity). A cost or calibration tool needs every phase scored.
// Phases are the leaves that get a checkpoint tag, <slug>/slice<N>/phase<M>, the same set such a tool
// counts, whether written as a heading (`### Slice 1 · Phase 2 — X`, `#### Phase 1.2 — X`)
// or a bold bullet (`**Phase 2 — X** · Complexity: 5 — ...`). The slice comes from a `Slice N` heading or
// a dotted `Phase N.M`, never from prose. Node, no dependencies.
//
// Usage: node .agent-kit/planning/plan-lint.mjs <plan.md>
// Output: one row per phase — `<id>  <score>  <OK|MISSING|INVALID>  L<line>  <title>`.
// Exit:   0 every phase OK · 1 a phase fails, or none found · 2 usage error or unreadable file.

import fs from "node:fs";

const file = process.argv[2];
if (!file) {
  console.error("usage: node plan-lint.mjs <plan.md>");
  process.exit(2);
}

let src;
try {
  src = fs.readFileSync(file, "utf8");
} catch (e) {
  console.error(`plan-lint: cannot read ${file}: ${e.code ?? e.message}`);
  process.exit(2);
}

const lines = src.split("\n");
const start = lines.findIndex((l) => /^##\s+Execution Plan\b/i.test(l));
const phases = [];
let slice = 1;
let fence = false;
let cur = null;

for (let i = start < 0 ? 0 : start + 1; i < lines.length; i++) {
  const line = lines[i];
  if (/^\s*```/.test(line)) fence = !fence;
  if (fence) continue;
  const heading = /^#{1,6}\s/.test(line);
  if (/^##\s/.test(line)) break; // next top-level section
  if (heading) cur = null;
  const sh = line.match(/^#+\s+Slice\s+(\d+)/);
  if (sh) slice = +sh[1];
  const m =
    (heading && line.match(/\bPhase\s+(\d+)(?:\.(\d+))?([a-z])?\b/)) ||
    line.match(/^\s*(?:[-*]\s+)?\*\*Phase\s+(\d+)(?:\.(\d+))?([a-z])?\b/);
  if (m) {
    const [s, p] = m[2] ? [m[1], m[2]] : [slice, m[1]];
    const title = line.slice(line.indexOf("Phase", m.index)).replace(/\*\*.*$/, "").trim().slice(0, 60);
    cur = { slice: `${s}`, num: p, letter: m[3] ?? "", line: i + 1, title, text: "" };
    phases.push(cur);
  }
  if (cur) cur.text += line + "\n";
}

const TASK = /^\s*[-*]\s+\[[ xX]\]/m;
// a phase split into sub-phases (3 -> 3a/3b) contributes the sub-phases only — but only when the parent
// holds no tasks of its own; a parent with tasks beside a lettered follow-up (3 + 3b) is a phase too
const isSplit = (p) =>
  !p.letter && !TASK.test(p.text) && phases.some((q) => q.slice === p.slice && q.num === p.num && q.letter === "a");
const kept = phases.filter((p) => !isSplit(p));

const AT = /(?:^[\s>*-]*|·\s*)Complexity:/m; // a field, not a mention in prose
let bad = 0;
for (const p of kept) {
  const at = p.text.match(AT);
  let score = "-";
  let status = "MISSING";
  if (at) {
    const rest = p.text.slice(at.index + at[0].length);
    const m = rest.match(/^\**[ \t]*`?([^\s`—–-]*)`?[ \t]*(?:[—–-][ \t]*([^\n]*))?/);
    score = m[1] || "-";
    const basis = (m[2] ?? "").replace(/[`\s]/g, "");
    status = ["1", "2", "3", "5", "8"].includes(score) && basis ? "OK" : "INVALID";
  }
  if (status !== "OK") bad++;
  console.log(`slice${p.slice}/phase${p.num}${p.letter}  ${score}  ${status}  L${p.line}  ${p.title}`);
}
if (!kept.length) {
  console.log("no phases found under ## Execution Plan");
  process.exit(1);
}
process.exit(bad ? 1 : 0);
