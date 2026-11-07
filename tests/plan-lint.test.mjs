// Hermetic regression check for common/.agent-kit/planning/plan-lint.mjs — kit meta-dev, never installed.
// Writes throwaway plans to a temp dir, runs the script on each, asserts the printed rows and exit code.
//
//   node plan-lint.test.mjs [path/to/plan-lint.mjs]    default: the kit's own copy

import { spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const script = path.resolve(process.argv[2] ?? path.join(here, "..", "common", ".agent-kit", "planning", "plan-lint.mjs"));
const template = path.join(here, "..", "common", ".agent-kit", "planning", "TEMPLATE.md");
const root = fs.mkdtempSync(path.join(os.tmpdir(), "plan-lint-test-"));

let failures = 0;
const check = (cond, msg) => {
  if (!cond) {
    failures++;
    console.error(`FAIL: ${msg}`);
  }
};

const run = (file) => {
  const r = spawnSync("node", [script, file], { encoding: "utf8" });
  const full = r.stdout.trim().split("\n");
  // verdict = `<id>  <score>  <status>`; the trailing `L<line>  <title>` is locator only
  return { code: r.status, full, rows: full.map((l) => l.split("  ").slice(0, 3).join("  ")), err: r.stderr };
};
function lint(name, plan) {
  const file = path.join(root, `${name}.md`);
  fs.writeFileSync(file, plan);
  return run(file);
}
const rowsAre = (r, name, want) => check(r.rows.join("|") === want.join("|"), `${name} rows: ${r.rows.join("|")}`);

try {
  // headings: valid (backticked whole, backticked value only, plain, hyphen), missing, letter, bad number, empty basis
  const h = lint(
    "headings",
    [
      "# x",
      "## Execution Plan",
      "### Slice 1 · Phase 1 — Spike: question",
      "Timebox: `2h`",
      "### Slice 1 · Phase 2 — A",
      "Complexity: `5 — 7 files · 4 bullets`",
      "### Slice 1 · Phase 3 — B",
      "Complexity: `3` — 5 files",
      "### Slice 2 · Phase 1 — C",
      "Complexity: 1 - 2 files",
      "### Slice 2 · Phase 2 — D",
      "Complexity: `M`",
      "### Slice 2 · Phase 3 — E",
      "Complexity: 4 — 3 files",
      "### Slice 2 · Phase 4 — F",
      "Complexity: 5 —",
      "## Notes",
      "### Phase 9 — outside the Execution Plan",
    ].join("\n")
  );
  check(h.code === 1, `headings: exit ${h.code}, want 1`);
  check(h.rows.length === 7, `headings: ${h.rows.length} rows, want 7 (Notes section must be ignored)`);
  rowsAre(h, "headings", [
    "slice1/phase1  -  MISSING",
    "slice1/phase2  5  OK",
    "slice1/phase3  3  OK",
    "slice2/phase1  1  OK",
    "slice2/phase2  M  INVALID",
    "slice2/phase3  4  INVALID",
    "slice2/phase4  5  INVALID",
  ]);
  // each row points at its source line and phase title
  check(h.full[1] === "slice1/phase2  5  OK  L5  Phase 2 — A", `headings locator: "${h.full[1]}"`);

  // bullet form, Complexity on the same or a wrapped line, a spike with its own score
  const b = lint(
    "bullets",
    [
      "## Execution Plan",
      "### Slice 1 phases",
      "**Phase 1 — Spike [sonnet]** · Complexity: 2 — 3 files",
      "",
      "- [x] shipped",
      "**Phase 2 — X [sonnet]** ·",
      "Complexity: 5 — 9 bullets",
      "### Slice 2 phases",
      "**Phase 1 — Y**",
      "- [ ] task",
    ].join("\n")
  );
  check(b.code === 1, `bullets: exit ${b.code}, want 1`);
  rowsAre(b, "bullets", ["slice1/phase1  2  OK", "slice1/phase2  5  OK", "slice2/phase1  -  MISSING"]);
  check(b.full[0] === "slice1/phase1  2  OK  L3  Phase 1 — Spike [sonnet]", `bullets locator: "${b.full[0]}"`);

  // all valid exits 0; a task-less parent split into 3a/3b drops out; fenced examples are ignored
  const ok = lint(
    "ok",
    [
      "## Execution Plan",
      "```",
      "### Phase 1 — example in a fence",
      "```",
      "### Phase 3 — split",
      "### Phase 3a — one",
      "Complexity: 3 — a",
      "### Phase 3b — two",
      "Complexity: `8` — b",
    ].join("\n")
  );
  check(ok.code === 0, `ok: exit ${ok.code}, want 0`);
  rowsAre(ok, "ok", ["slice1/phase3a  3  OK", "slice1/phase3b  8  OK"]);

  // a follow-up 3b (no 3a) keeps its parent 3; so does a 3a split whose parent holds tasks of its own
  const fu = lint(
    "follow-up",
    [
      "## Execution Plan",
      "### Slice 1 — A",
      "#### Phase 3 — real leaf",
      "- [ ] task",
      "#### Phase 3b — follow-up",
      "Complexity: 2 — 3 files",
      "### Slice 2 — B",
      "#### Phase 1 — has tasks",
      "- [x] done",
      "#### Phase 1a — sub",
      "Complexity: 2 — 3 files",
    ].join("\n")
  );
  check(fu.code === 1, `follow-up: exit ${fu.code}, want 1`);
  rowsAre(fu, "follow-up", [
    "slice1/phase3  -  MISSING",
    "slice1/phase3b  2  OK",
    "slice2/phase1  -  MISSING",
    "slice2/phase1a  2  OK",
  ]);

  // dotted Phase N.M is slice N / phase M; a phase heading naming another slice does not move the slice
  const d = lint(
    "dotted",
    [
      "## Execution Plan",
      "### Slice 2 — B",
      "#### Phase 1.1 — a",
      "Complexity: 3 — x",
      "#### Phase 2.1 — consume Slice 1 output",
      "Complexity: 3 — x",
      "#### Phase 2 — next, after Slice 7 lands",
      "Complexity: 3 — x",
      "#### Phase 3 — still slice 2",
      "Complexity: 3 — x",
    ].join("\n")
  );
  check(d.code === 0, `dotted: exit ${d.code}, want 0`);
  rowsAre(d, "dotted", ["slice1/phase1  3  OK", "slice2/phase1  3  OK", "slice2/phase2  3  OK", "slice2/phase3  3  OK"]);

  // a Complexity mention in prose is not the field; a `---` inside a phase does not end it
  const p = lint(
    "prose-hr",
    [
      "## Execution Plan",
      "### Phase 1 — prose only",
      "- [ ] Note: the `Complexity: 5 — rubric` example in the docs is stale",
      "See Complexity: 3 — not a field either",
      "### Phase 2 — rule inside",
      "- [ ] task",
      "",
      "---",
      "",
      "> Complexity: 3 — after the rule",
    ].join("\n")
  );
  check(p.code === 1, `prose-hr: exit ${p.code}, want 1`);
  rowsAre(p, "prose-hr", ["slice1/phase1  -  MISSING", "slice1/phase2  3  OK"]);

  const none = lint("none", "# x\n## Execution Plan\nnothing\n");
  check(none.code === 1, `no phases: exit ${none.code}, want 1`);

  // an unreadable file is a usage error (2), never a gate failure (1)
  const gone = run(path.join(root, "missing.md"));
  check(gone.code === 2, `missing file: exit ${gone.code}, want 2`);
  check(gone.err.trim().split("\n").length === 1, `missing file: stderr not one line: ${gone.err}`);

  // the template passes its own gate
  const t = run(template);
  check(t.code === 0, `TEMPLATE.md: exit ${t.code}, want 0 — ${t.full.join("|")}`);
} finally {
  fs.rmSync(root, { recursive: true, force: true });
}

if (failures) {
  console.error(`${failures} check(s) failed`);
  process.exit(1);
}
console.log("plan-lint: all checks passed");
