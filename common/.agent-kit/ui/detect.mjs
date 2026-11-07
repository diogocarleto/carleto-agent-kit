#!/usr/bin/env node
// Mechanical UI "AI tells" detector — public facade. Platform/framework knowledge lives
// in validators/*; this file only does arg parsing, file selection, token-file exemption,
// delegation, output formatting, and exit codes. It rarely needs to change.
//
// Advisory by design: it never blocks, it surfaces. Visual judgment owns the rest.
// Cross-platform via validators: web, Svelte, React, Angular, React Native, iOS, Android.
//
// Usage:
//   node detect.mjs [files...]      scan the given files
//   node detect.mjs                 scan changed files (git)
//   node detect.mjs --json          machine-readable output
//   node detect.mjs --strict        exit 1 if any finding (for CI)

import { execSync } from "node:child_process";
import fs from "node:fs";
import { isScannableFile, validateFile } from "./validators/index.mjs";

const args = process.argv.slice(2);
const json = args.includes("--json");
const strict = args.includes("--strict");
const files = args.filter((a) => !a.startsWith("--"));

// Files that legitimately DEFINE the palette/type/motion — never flag them. Covers web
// (app.css, tokens.*), Android (colors.xml, themes.xml, Color.kt, Type.kt), iOS (*.xcassets,
// Color.swift, Theme.swift). NB: web "styles.css" is general styling, not a token file.
const TOKEN_FILE_RE =
  /^(app|colors?|tokens?|variables?|palette|themes?|typography|dimens|spacing|motion|easing|radii?|shadows?|type|fonts?)\.(css|scss|sass|less|ts|js|mjs|kt|kts|swift|xml)$/i;
const TOKEN_DIR_RE = /(^|\/)(theme|themes|tokens|design-tokens|\.xcassets)(\/|$)/i;
const DETECTOR_IMPL_RE = /(^|\/)\.agent-kit\/ui\/(detect\.mjs|validators\/)/i;

const isTokenFile = (p) => {
  const base = (p.split("/").pop() || "").toLowerCase();
  return TOKEN_FILE_RE.test(base) || TOKEN_DIR_RE.test(p);
};

const gitList = (cmd) =>
  execSync(cmd, { encoding: "utf8" })
    .split("\n")
    .map((s) => s.trim())
    .filter(Boolean);

function targetFiles() {
  if (files.length) return files;
  try {
    const changed = [
      ...gitList("git diff --name-only --diff-filter=ACM HEAD"),
      ...gitList("git diff --name-only --diff-filter=ACM --cached"),
      ...gitList("git ls-files --others --exclude-standard"),
    ];
    return [...new Set(changed)].filter(
      // auto-scan is UI-only: skip backend source, build output, and deps.
      // (Explicitly-named files passed as args bypass this filter.)
      // ⚠ Exclude src/**/java by FILE, not by path: Android Studio puts Compose Kotlin at
      // app/src/main/java/**/*.kt by default, so filtering the whole directory silently skipped every
      // file validators/android.mjs exists to check. Backend .java is still skipped.
      (p) =>
        !(/\/src\/(main|test)\/java\//.test(p) && /\.java$/i.test(p)) &&
        !/(^|\/)(target|node_modules|build)\//.test(p)
    );
  } catch {
    return [];
  }
}

const findings = [];

for (const file of targetFiles()) {
  if (!isScannableFile(file) || isTokenFile(file) || DETECTOR_IMPL_RE.test(file)) continue;
  let text;
  try {
    text = fs.readFileSync(file, "utf8");
  } catch {
    continue;
  }
  findings.push(...validateFile({ file, text }));
}

if (json) {
  process.stdout.write(JSON.stringify({ findings }, null, 2) + "\n");
} else if (findings.length) {
  process.stdout.write(`UI tells (${findings.length}) — advisory, verify visually:\n`);
  for (const f of findings) {
    process.stdout.write(`  ${f.file}:${f.line}  [${f.rule}/${f.platform}] ${f.msg}\n`);
  }
} else {
  process.stdout.write("UI detector: no mechanical tells found.\n");
}

process.exit(strict && findings.length ? 1 : 0);
